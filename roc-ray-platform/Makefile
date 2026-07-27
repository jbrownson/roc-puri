ROC ?= roc
ROC_CACHE_DIR ?= $(CURDIR)/.cache/roc
ROC_RAY_VERSION ?= 0.8.0
ROC_RAY_BUNDLE ?= HXKssyTXxLLu4TStDfgo9uvjnkT5mGJoRqKcvV2khjcw
ROC_RAY_URL ?= https://github.com/lukewilliamboswell/roc-ray/releases/download/$(ROC_RAY_VERSION)/$(ROC_RAY_BUNDLE).tar.zst
ROC_RAY_ARCHIVE ?= $(CURDIR)/.cache/roc-ray/$(ROC_RAY_BUNDLE).tar.zst
HOST_MACHINE := $(shell uname -m)
ROC_RAY_STAMP := $(CURDIR)/targets/.installed-$(ROC_RAY_VERSION)-$(HOST_MACHINE)
ROC_RAY_ADAPTER = $(CURDIR)/targets/$(ROC_HOST_TARGET)/puri_roc_ray_adapter.o
ROC_SOURCES := $(wildcard *.roc)

.DEFAULT_GOAL := check

ifeq ($(HOST_MACHINE),arm64)
ROC_HOST_TARGET := arm64mac
CC_HOST_ARCH := arm64
else ifeq ($(HOST_MACHINE),x86_64)
ROC_HOST_TARGET := x64mac
CC_HOST_ARCH := x86_64
else
$(error Unsupported macOS host architecture: $(HOST_MACHINE))
endif

.PHONY: fmt fmt-check check test adapter-test native-deps clean

fmt:
	$(ROC) fmt $(ROC_SOURCES)

fmt-check:
	$(ROC) fmt --check $(ROC_SOURCES)

check: fmt-check
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check main.roc

test: adapter-test

adapter-test: build/roc-ray-adapter-test
	build/roc-ray-adapter-test

build/roc-ray-adapter-test: roc_ray_adapter.c tests/roc_ray_adapter_test.c
	mkdir -p build
	cc -std=c11 -Wall -Wextra -Werror tests/roc_ray_adapter_test.c -o build/roc-ray-adapter-test

native-deps: $(ROC_RAY_STAMP) $(ROC_RAY_ADAPTER)

$(ROC_RAY_STAMP):
	mkdir -p $(dir $(ROC_RAY_ARCHIVE)) targets
	curl -fL $(ROC_RAY_URL) -o $(ROC_RAY_ARCHIVE)
	tar -xf $(ROC_RAY_ARCHIVE) -C . targets/$(ROC_HOST_TARGET) targets/macos-sysroot
	touch $@

$(ROC_RAY_ADAPTER): roc_ray_adapter.c $(ROC_RAY_STAMP)
	mkdir -p $(dir $@)
	cc -std=c11 -Wall -Wextra -Werror -arch $(CC_HOST_ARCH) -c $< -o $@

clean:
	rm -rf build .cache targets
