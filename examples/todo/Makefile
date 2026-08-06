ROC ?= roc
ROC_BINARY := $(shell command -v $(ROC) 2>/dev/null)
ROC_CACHE_DIR ?= $(CURDIR)/.cache/roc
MACOS_SDK ?= $(shell xcrun --show-sdk-path)
HOST_MACHINE := $(shell uname -m)
NATIVE_BINARY := PuriTodoDemo
NATIVE_DEV_BUILD_TMP := $(CURDIR)/build/native/PuriTodoDemo-dev.new
NATIVE_SPEED_BINARY := $(CURDIR)/build/native/PuriTodoDemo-speed
NATIVE_SPEED_BUILD_TMP := $(CURDIR)/build/native/PuriTodoDemo-speed.new

.DEFAULT_GOAL := check

TODO_TEST_SOURCE := TodoTests.roc
TODO_SOURCES := $(filter-out $(TODO_TEST_SOURCE),$(wildcard *.roc))
DEPENDENCY_SOURCES := $(wildcard ../roc-ray-platform/*.roc) ../roc-ray-platform/Makefile ../roc-ray-platform/roc_ray_adapter.c
FORMAT_SOURCES := $(sort $(wildcard *.roc tests/platform/*.roc))

ifeq ($(HOST_MACHINE),arm64)
ROC_HOST_TARGET := arm64mac
CC_HOST_ARCH := arm64
else ifeq ($(HOST_MACHINE),x86_64)
ROC_HOST_TARGET := x64mac
CC_HOST_ARCH := x86_64
else
$(error Unsupported macOS host architecture: $(HOST_MACHINE))
endif

.PHONY: fmt fmt-check check test native-deps native-build native-headless native-run native-speed-build native-speed-run clean

fmt:
	$(ROC) fmt $(FORMAT_SOURCES)

fmt-check:
	$(ROC) fmt --check $(FORMAT_SOURCES)

check: fmt-check
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check main.roc
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check TodoTests.roc

test: tests/platform/targets/$(ROC_HOST_TARGET)/libhost.a tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) TodoTests.roc

native-deps:
	$(MAKE) -C ../roc-ray-platform native-deps

native-build: $(NATIVE_BINARY)

$(NATIVE_BINARY): Makefile $(ROC_BINARY) $(TODO_SOURCES) $(DEPENDENCY_SOURCES) | native-deps
	mkdir -p $(dir $(NATIVE_DEV_BUILD_TMP))
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --no-cache --opt=dev --output=$(NATIVE_DEV_BUILD_TMP) main.roc
	mv $(NATIVE_DEV_BUILD_TMP) $@

native-headless: $(NATIVE_BINARY)
	./$(NATIVE_BINARY) --headless --headless-frames=3

native-run: $(NATIVE_BINARY)
	./$(NATIVE_BINARY)

native-speed-build: $(NATIVE_SPEED_BINARY)

$(NATIVE_SPEED_BINARY): Makefile $(ROC_BINARY) $(TODO_SOURCES) $(DEPENDENCY_SOURCES) | native-deps
	mkdir -p $(dir $(NATIVE_SPEED_BUILD_TMP))
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --no-cache --opt=speed --output=$(NATIVE_SPEED_BUILD_TMP) main.roc
	mv $(NATIVE_SPEED_BUILD_TMP) $@

native-speed-run: $(NATIVE_SPEED_BINARY)
	$(NATIVE_SPEED_BINARY)

tests/platform/targets/$(ROC_HOST_TARGET)/libhost.a: tests/platform/host.c
	mkdir -p build tests/platform/targets/$(ROC_HOST_TARGET)
	cc -std=c11 -arch $(CC_HOST_ARCH) -c tests/platform/host.c -o build/test-host-$(HOST_MACHINE).o
	ar rcs $@ build/test-host-$(HOST_MACHINE).o

tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd:
	mkdir -p tests/platform/targets/macos-sysroot/usr/lib
	cp $(MACOS_SDK)/usr/lib/libSystem.tbd tests/platform/targets/macos-sysroot/usr/lib/libSystem.tbd

clean:
	rm -rf build .cache tests/platform/targets
	rm -f $(NATIVE_BINARY)
