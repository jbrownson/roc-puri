ROC ?= .tools/roc/bin/roc
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
ROC_RAY_HOST_PATCH_VERSION ?= mouse-edge-queue-v1
ROC_RAY_HOST_PATCH ?= $(CURDIR)/roc-ray-host-patch/targets/$(ROC_HOST_TARGET)/libhost.a
ROC_RAY_HOST_PATCH_STAMP ?= $(CURDIR)/roc-ray-platform/targets/.patched-$(ROC_RAY_VERSION)-$(ROC_RAY_HOST_PATCH_VERSION)-$(HOST_MACHINE)
HOST_MACHINE := $(shell uname -m)

NATIVE_ROC_SOURCES := \
	$(filter-out src/%Tests.roc src/%Conformance.roc src/%Generated.roc src/RocSpecialization%.roc,$(wildcard src/*.roc)) \
	$(wildcard roc-ray-platform/*.roc)

ifeq ($(HOST_MACHINE),arm64)
ROC_HOST_TARGET := arm64mac
CC_HOST_ARCH := arm64
else ifeq ($(HOST_MACHINE),x86_64)
ROC_HOST_TARGET := x64mac
CC_HOST_ARCH := x86_64
else
$(error Unsupported macOS host architecture: $(HOST_MACHINE))
endif

.PHONY: check test conformance puri-test specialization-repro fuzz-flat fuzz-tree fuzz-text oracle mouse-edge-repro mouse-edge-repro-slow native-deps native-check native-build native-headless native-run clean

check:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/Geometry2d.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/Roclay.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/RoclayFlatConformance.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/RoclayTreeConformance.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/RoclayTextConformance.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/RoclayPlacementTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriHandler.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriHandlerTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriCanvas.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriCanvasRecording.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriCanvasTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/Puri.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriInteract.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriButton.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriCheckbox.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriLineEdit.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriLineEditWidget.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriLineEditWidgetTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriButtonTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriCheckboxTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriTodo.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriTodoTests.roc

test:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test src/Geometry2d.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test src/Roclay.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test src/PuriLineEdit.roc

conformance: test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/RoclayPlacementTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriHandlerTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriCanvasTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriLineEditWidgetTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriButtonTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriCheckboxTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriTodoTests.roc

puri-test: test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriHandlerTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriCanvasTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriLineEditWidgetTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriButtonTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriCheckboxTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriTodoTests.roc

specialization-repro: test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	/usr/bin/time -p env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build src/RocSpecializationMinimal.roc
	/usr/bin/time -p env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build src/RocSpecializationRoclay.roc
	/usr/bin/time -p env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build src/RocSpecializationPuri.roc

native-deps: $(ROC_RAY_HOST_PATCH_STAMP)

native-check:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriRocRayDemo.roc

native-build: PuriRocRayDemo

PuriRocRayDemo: Makefile .roc-version $(ROC_RAY_HOST_PATCH_STAMP) $(NATIVE_ROC_SOURCES)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build src/PuriRocRayDemo.roc

native-headless: PuriRocRayDemo
	./PuriRocRayDemo --headless --headless-frames=3

native-run: PuriRocRayDemo
	./PuriRocRayDemo

fuzz-flat: build/clay-oracle test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	$(PYTHON) tools/generate_flat_conformance.py --oracle build/clay-oracle --output src/RoclayFlatGenerated.roc --corpus-output build/roclay-flat-corpus.txt --cases $(FUZZ_CASES) --seed $(FUZZ_SEED)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/RoclayFlatGenerated.roc

fuzz-tree: build/clay-oracle test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	$(PYTHON) tools/generate_tree_conformance.py --oracle build/clay-oracle --output src/RoclayTreeGenerated.roc --corpus-output build/roclay-tree-corpus.txt --cases $(TREE_FUZZ_CASES) --seed $(TREE_FUZZ_SEED)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/RoclayTreeGenerated.roc

fuzz-text: build/clay-oracle test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	$(PYTHON) tools/generate_text_conformance.py --oracle build/clay-oracle --output src/RoclayTextGenerated.roc --corpus-output build/roclay-text-corpus.txt --cases $(TEXT_FUZZ_CASES) --seed $(TEXT_FUZZ_SEED)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/RoclayTextGenerated.roc

oracle: build/clay-oracle
	build/clay-oracle

mouse-edge-repro: build/raylib-mouse-edges
	build/raylib-mouse-edges

mouse-edge-repro-slow: build/raylib-mouse-edges
	build/raylib-mouse-edges --slow

build/raylib-mouse-edges: repro/raylib_mouse_edges.c $(ROC_RAY_STAMP)
	mkdir -p build
	cc -std=c11 repro/raylib_mouse_edges.c roc-ray-platform/targets/$(ROC_HOST_TARGET)/libraylib.a \
		-framework Cocoa -framework IOKit -framework OpenGL -framework CoreVideo \
		-o $@

build/clay-oracle: oracle/clay_oracle.c oracle/vendor/clay/clay.h
	mkdir -p build
	cc -w -std=c99 oracle/clay_oracle.c -o build/clay-oracle

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

$(ROC_RAY_HOST_PATCH_STAMP): $(ROC_RAY_STAMP) $(ROC_RAY_HOST_PATCH)
	cp $(ROC_RAY_HOST_PATCH) roc-ray-platform/targets/$(ROC_HOST_TARGET)/libhost.a
	touch $@

clean:
	rm -rf build test-platform/targets
