ROC ?= roc
ROC_CACHE_DIR ?= $(CURDIR)/.cache/roc
MACOS_SDK ?= $(shell xcrun --show-sdk-path)
HOST_MACHINE := $(shell uname -m)
DIST_DIR ?= build/dist

.DEFAULT_GOAL := check

PURI_SOURCES := $(wildcard *.roc)
TEST_SOURCES := $(wildcard tests/*.roc)
FORMAT_SOURCES := $(sort $(PURI_SOURCES) $(TEST_SOURCES) $(wildcard tests/support/*.roc tests/platform/*.roc))

ifeq ($(HOST_MACHINE),arm64)
ROC_HOST_TARGET := arm64mac
CC_HOST_ARCH := arm64
else ifeq ($(HOST_MACHINE),x86_64)
ROC_HOST_TARGET := x64mac
CC_HOST_ARCH := x86_64
else
$(error Unsupported macOS host architecture: $(HOST_MACHINE))
endif

.PHONY: fmt fmt-check check test docs dist conformance run native-run native-speed-run clean

fmt:
	$(ROC) fmt $(FORMAT_SOURCES)

fmt-check:
	$(ROC) fmt --check $(FORMAT_SOURCES)

check: fmt-check
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check tests/support/main.roc
	@for source in $(TEST_SOURCES); do \
		env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check $$source || exit 1; \
	done

test:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test main.roc
	$(MAKE) conformance

docs:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) docs main.roc --output=build/docs

dist: check
	mkdir -p $(DIST_DIR)
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) bundle main.roc --output-dir $(DIST_DIR)

conformance: tests/platform/targets/$(ROC_HOST_TARGET)/libhost.a tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	@for source in $(TEST_SOURCES); do \
		env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) $$source || exit 1; \
	done

run native-run:
	$(MAKE) -C examples/todo native-run

native-speed-run:
	$(MAKE) -C examples/todo native-speed-run

tests/platform/targets/$(ROC_HOST_TARGET)/libhost.a: tests/platform/host.c
	mkdir -p build tests/platform/targets/$(ROC_HOST_TARGET)
	cc -std=c11 -arch $(CC_HOST_ARCH) -c tests/platform/host.c -o build/test-host-$(HOST_MACHINE).o
	ar rcs $@ build/test-host-$(HOST_MACHINE).o

tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd:
	mkdir -p tests/platform/targets/macos-sysroot/usr/lib
	cp $(MACOS_SDK)/usr/lib/libSystem.tbd tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd

clean:
	rm -rf build .cache tests/platform/targets
	$(MAKE) -C examples/roc-ray-platform clean
	$(MAKE) -C examples/todo clean
