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
HOST_MACHINE := $(shell uname -m)

ifeq ($(HOST_MACHINE),arm64)
ROC_HOST_TARGET := arm64mac
CC_HOST_ARCH := arm64
else ifeq ($(HOST_MACHINE),x86_64)
ROC_HOST_TARGET := x64mac
CC_HOST_ARCH := x86_64
else
$(error Unsupported macOS host architecture: $(HOST_MACHINE))
endif

.PHONY: check test conformance puri-test fuzz-flat fuzz-tree fuzz-text oracle clean

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
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriLineEdit.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriLineEditWidget.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check src/PuriLineEditWidgetTests.roc

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

puri-test: test-platform/targets/$(ROC_HOST_TARGET)/libhost.a test-platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriHandlerTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriCanvasTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriTests.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) src/PuriLineEditWidgetTests.roc

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

clean:
	rm -rf build test-platform/targets
