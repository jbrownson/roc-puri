ROC ?= roc
PYTHON ?= python3
ROC_CACHE_DIR ?= $(CURDIR)/.cache/roc
MACOS_SDK ?= $(shell xcrun --show-sdk-path)
FUZZ_CASES ?= 250
FUZZ_SEED ?= 90415383257433
TREE_FUZZ_CASES ?= 50
TREE_FUZZ_SEED ?= 6075990657347146073
TEXT_FUZZ_CASES ?= 250
TEXT_FUZZ_SEED ?= 6072351293270905177
HOST_MACHINE := $(shell uname -m)

.DEFAULT_GOAL := check

ROCLAY_SOURCES := $(wildcard *.roc)
TEST_SOURCES := $(filter-out tests/Roclay%Generated.roc tests/RoclayTreeReduced%.roc,$(wildcard tests/*.roc))
FORMAT_SOURCES := $(sort $(ROCLAY_SOURCES) $(TEST_SOURCES) $(wildcard tests/platform/*.roc))

ifeq ($(HOST_MACHINE),arm64)
ROC_HOST_TARGET := arm64mac
CC_HOST_ARCH := arm64
else ifeq ($(HOST_MACHINE),x86_64)
ROC_HOST_TARGET := x64mac
CC_HOST_ARCH := x86_64
else
$(error Unsupported macOS host architecture: $(HOST_MACHINE))
endif

.PHONY: fmt fmt-check check test docs conformance fuzz-flat fuzz-tree fuzz-text oracle clean

fmt:
	$(ROC) fmt $(FORMAT_SOURCES)

fmt-check:
	$(ROC) fmt --check $(FORMAT_SOURCES)

check: fmt-check
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check tests/main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check tests/RoclayPlacementTests.roc

test:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test main.roc
	$(MAKE) conformance

docs:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) docs main.roc --output=build/docs

conformance: tests/platform/targets/$(ROC_HOST_TARGET)/libhost.a tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) tests/RoclayPlacementTests.roc

fuzz-flat: build/clay-oracle tests/platform/targets/$(ROC_HOST_TARGET)/libhost.a tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	$(PYTHON) tests/tools/generate_flat_conformance.py --oracle build/clay-oracle --output tests/RoclayFlatGenerated.roc --corpus-output build/roclay-flat-corpus.txt --cases $(FUZZ_CASES) --seed $(FUZZ_SEED)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) tests/RoclayFlatGenerated.roc

fuzz-tree: build/clay-oracle tests/platform/targets/$(ROC_HOST_TARGET)/libhost.a tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	$(PYTHON) tests/tools/generate_tree_conformance.py --oracle build/clay-oracle --output tests/RoclayTreeGenerated.roc --corpus-output build/roclay-tree-corpus.txt --cases $(TREE_FUZZ_CASES) --seed $(TREE_FUZZ_SEED)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) tests/RoclayTreeGenerated.roc

fuzz-text: build/clay-oracle tests/platform/targets/$(ROC_HOST_TARGET)/libhost.a tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	$(PYTHON) tests/tools/generate_text_conformance.py --oracle build/clay-oracle --output tests/RoclayTextGenerated.roc --corpus-output build/roclay-text-corpus.txt --cases $(TEXT_FUZZ_CASES) --seed $(TEXT_FUZZ_SEED)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) tests/RoclayTextGenerated.roc

oracle: build/clay-oracle
	build/clay-oracle

build/clay-oracle: tests/oracle/clay_oracle.c tests/oracle/vendor/clay/clay.h
	mkdir -p build
	cc -w -std=c99 tests/oracle/clay_oracle.c -o build/clay-oracle

tests/platform/targets/$(ROC_HOST_TARGET)/libhost.a: tests/platform/host.c
	mkdir -p build tests/platform/targets/$(ROC_HOST_TARGET)
	cc -std=c11 -arch $(CC_HOST_ARCH) -c tests/platform/host.c -o build/test-host-$(HOST_MACHINE).o
	ar rcs $@ build/test-host-$(HOST_MACHINE).o

tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd:
	mkdir -p tests/platform/targets/macos-sysroot/usr/lib
	cp $(MACOS_SDK)/usr/lib/libSystem.tbd tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd

clean:
	rm -rf build .cache tests/platform/targets
	rm -f tests/RoclayFlatGenerated.roc tests/RoclayTreeGenerated.roc tests/RoclayTextGenerated.roc tests/RoclayTreeReduced*.roc
