ROC ?= roc
ROC_BINARY := $(shell command -v $(ROC) 2>/dev/null)
PYTHON ?= python3
ROC_CACHE_DIR ?= $(CURDIR)/.cache/roc
MACOS_SDK ?= $(shell xcrun --show-sdk-path)
FUZZ_CASES ?= 250
FUZZ_SEED ?= 90415383257433
TREE_FUZZ_CASES ?= 50
TREE_FUZZ_SEED ?= 6075990657347146073
TEXT_FUZZ_CASES ?= 250
TEXT_FUZZ_SEED ?= 6072351293270905177
ROC_RAY_VERSION ?= 0.8.0
ROC_RAY_BUNDLE ?= HXKssyTXxLLu4TStDfgo9uvjnkT5mGJoRqKcvV2khjcw
ROC_RAY_URL ?= https://github.com/lukewilliamboswell/roc-ray/releases/download/$(ROC_RAY_VERSION)/$(ROC_RAY_BUNDLE).tar.zst
ROC_RAY_ARCHIVE ?= $(CURDIR)/.cache/roc-ray/$(ROC_RAY_BUNDLE).tar.zst
ROC_RAY_STAMP ?= $(CURDIR)/roc-ray-platform/targets/.installed-$(ROC_RAY_VERSION)-$(HOST_MACHINE)
ROC_RAY_ADAPTER ?= $(CURDIR)/roc-ray-platform/targets/$(ROC_HOST_TARGET)/puri_roc_ray_adapter.o
NATIVE_DEV_BUILD_TMP ?= $(CURDIR)/build/native/PuriRocRayDemo-dev.new
NATIVE_SPEED_BINARY ?= $(CURDIR)/build/native/PuriRocRayDemo-speed
NATIVE_SPEED_BUILD_TMP ?= $(CURDIR)/build/native/PuriRocRayDemo-speed.new
HOST_MACHINE := $(shell uname -m)

GEOMETRY_SOURCES := $(wildcard geometry/*.roc)
ROCLAY_SOURCES := $(wildcard roclay/*.roc)
PURI_SOURCES := $(wildcard puri/*.roc)
PURI_ROCLAY_SOURCES := $(wildcard puri-roclay/*.roc)
TODO_TEST_SOURCE := examples/todo/TodoTests.roc
TODO_SOURCES := $(filter-out $(TODO_TEST_SOURCE),$(wildcard examples/todo/*.roc))
ROCLAY_TEST_SOURCES := $(filter-out tests/roclay/%Generated.roc tests/roclay/RoclayTreeReduced%.roc,$(wildcard tests/roclay/*.roc))
ROCLAY_CHECK_SOURCES := tests/roclay/main.roc tests/roclay/RoclayPlacementTests.roc
PURI_TEST_SOURCES := $(wildcard tests/puri/*.roc) $(TODO_TEST_SOURCE)
PURI_ROCLAY_TEST_SOURCES := $(wildcard tests/puri-roclay/*.roc)
PURI_TEST_SUPPORT := tests/puri/support/main.roc
SPECIALIZATION_SOURCES := $(wildcard compiler-repro/specialization/*.roc)
NATIVE_ROC_SOURCES := $(GEOMETRY_SOURCES) $(ROCLAY_SOURCES) $(PURI_SOURCES) $(PURI_ROCLAY_SOURCES) $(TODO_SOURCES) $(wildcard roc-ray-platform/*.roc)
ROC_FORMAT_SOURCES := $(sort \
	$(filter-out tests/roclay/%Generated.roc tests/roclay/RoclayTreeReduced%.roc, \
		$(shell find geometry roclay puri puri-roclay examples tests compiler-repro roc-ray-platform test-platform -type f -name '*.roc')))

ifeq ($(HOST_MACHINE),arm64)
ROC_HOST_TARGET := arm64mac
CC_HOST_ARCH := arm64
else ifeq ($(HOST_MACHINE),x86_64)
ROC_HOST_TARGET := x64mac
CC_HOST_ARCH := x86_64
else
$(error Unsupported macOS host architecture: $(HOST_MACHINE))
endif

.PHONY: fmt fmt-check check test docs roc-ray-adapter-test conformance puri-test specialization-repro fuzz-flat fuzz-tree fuzz-text oracle native-deps native-check native-build native-headless native-run native-speed-build native-speed-run clean

fmt:
	$(ROC) fmt $(ROC_FORMAT_SOURCES)

fmt-check:
	$(ROC) fmt --check $(ROC_FORMAT_SOURCES)

check: fmt-check
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check geometry/main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check roclay/main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check puri/main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check puri-roclay/main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check $(PURI_TEST_SUPPORT)
	@for source in $(ROCLAY_CHECK_SOURCES) $(PURI_TEST_SOURCES) $(PURI_ROCLAY_TEST_SOURCES) $(SPECIALIZATION_SOURCES); do \
		env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check $$source || exit 1; \
	done

test: roc-ray-adapter-test
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test geometry/main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test roclay/main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test puri/main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test puri-roclay/main.roc

docs:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) docs geometry/main.roc --output=build/docs/geometry
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) docs roclay/main.roc --output=build/docs/roclay
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) docs puri/main.roc --output=build/docs/puri
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) docs puri-roclay/main.roc --output=build/docs/puri-roclay

roc-ray-adapter-test: build/roc-ray-adapter-test
	build/roc-ray-adapter-test

build/roc-ray-adapter-test: roc-ray-platform/roc_ray_adapter.c roc-ray-platform/roc_ray_adapter_test.c
	mkdir -p build
	cc -std=c11 -Wall -Wextra -Werror roc-ray-platform/roc_ray_adapter_test.c -o build/roc-ray-adapter-test

conformance: test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	@for source in tests/roclay/RoclayPlacementTests.roc $(PURI_TEST_SOURCES) $(PURI_ROCLAY_TEST_SOURCES); do \
		env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) $$source || exit 1; \
	done

puri-test: test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	@for source in $(PURI_TEST_SOURCES) $(PURI_ROCLAY_TEST_SOURCES); do \
		env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) $$source || exit 1; \
	done

specialization-repro: test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	/usr/bin/time -p env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build compiler-repro/specialization/RocSpecializationMinimal.roc
	/usr/bin/time -p env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build compiler-repro/specialization/RocSpecializationRoclay.roc
	/usr/bin/time -p env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build compiler-repro/specialization/RocSpecializationPuri.roc

native-deps: $(ROC_RAY_STAMP) $(ROC_RAY_ADAPTER)

native-check:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check examples/todo/main.roc

native-build: PuriRocRayDemo

PuriRocRayDemo: Makefile $(ROC_BINARY) $(ROC_RAY_STAMP) $(ROC_RAY_ADAPTER) $(NATIVE_ROC_SOURCES)
	mkdir -p $(dir $(NATIVE_DEV_BUILD_TMP))
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --no-cache --opt=dev --output=$(NATIVE_DEV_BUILD_TMP) examples/todo/main.roc
	mv $(NATIVE_DEV_BUILD_TMP) $@

native-headless: PuriRocRayDemo
	./PuriRocRayDemo --headless --headless-frames=3

native-run: PuriRocRayDemo
	./PuriRocRayDemo

native-speed-build: $(NATIVE_SPEED_BINARY)

$(NATIVE_SPEED_BINARY): Makefile $(ROC_BINARY) $(ROC_RAY_STAMP) $(ROC_RAY_ADAPTER) $(NATIVE_ROC_SOURCES)
	mkdir -p $(dir $(NATIVE_SPEED_BUILD_TMP))
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --no-cache --opt=speed --output=$(NATIVE_SPEED_BUILD_TMP) examples/todo/main.roc
	mv $(NATIVE_SPEED_BUILD_TMP) $@

native-speed-run: $(NATIVE_SPEED_BINARY)
	$(NATIVE_SPEED_BINARY)

fuzz-flat: build/clay-oracle test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	$(PYTHON) tools/generate_flat_conformance.py --oracle build/clay-oracle --output tests/roclay/RoclayFlatGenerated.roc --corpus-output build/roclay-flat-corpus.txt --cases $(FUZZ_CASES) --seed $(FUZZ_SEED)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) tests/roclay/RoclayFlatGenerated.roc

fuzz-tree: build/clay-oracle test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	$(PYTHON) tools/generate_tree_conformance.py --oracle build/clay-oracle --output tests/roclay/RoclayTreeGenerated.roc --corpus-output build/roclay-tree-corpus.txt --cases $(TREE_FUZZ_CASES) --seed $(TREE_FUZZ_SEED)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) tests/roclay/RoclayTreeGenerated.roc

fuzz-text: build/clay-oracle test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	$(PYTHON) tools/generate_text_conformance.py --oracle build/clay-oracle --output tests/roclay/RoclayTextGenerated.roc --corpus-output build/roclay-text-corpus.txt --cases $(TEXT_FUZZ_CASES) --seed $(TEXT_FUZZ_SEED)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) tests/roclay/RoclayTextGenerated.roc

oracle: build/clay-oracle
	build/clay-oracle

build/clay-oracle: tests/roclay/oracle/clay_oracle.c tests/roclay/oracle/vendor/clay/clay.h
	mkdir -p build
	cc -w -std=c99 tests/roclay/oracle/clay_oracle.c -o build/clay-oracle

test-platform/targets/$(ROC_HOST_TARGET)/libhost.a: test-platform/host.c
	mkdir -p build test-platform/targets/$(ROC_HOST_TARGET)
	cc -std=c11 -arch $(CC_HOST_ARCH) -c test-platform/host.c -o build/test-host-$(HOST_MACHINE).o
	ar rcs $@ build/test-host-$(HOST_MACHINE).o

test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd:
	mkdir -p test-platform/targets/macos-sysroot/usr/lib
	cp $(MACOS_SDK)/usr/lib/libSystem.tbd test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd

$(ROC_RAY_STAMP):
	mkdir -p $(dir $(ROC_RAY_ARCHIVE)) roc-ray-platform/targets
	curl -fL $(ROC_RAY_URL) -o $(ROC_RAY_ARCHIVE)
	tar -xf $(ROC_RAY_ARCHIVE) -C roc-ray-platform targets/$(ROC_HOST_TARGET) targets/macos-sysroot
	touch $@

$(ROC_RAY_ADAPTER): roc-ray-platform/roc_ray_adapter.c $(ROC_RAY_STAMP)
	mkdir -p $(dir $@)
	cc -std=c11 -Wall -Wextra -Werror -arch $(CC_HOST_ARCH) -c $< -o $@

clean:
	rm -rf build test-platform/targets
	rm -f PuriRocRayDemo
