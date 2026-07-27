SHELL := /bin/sh

ROC ?= roc
ROC_BINARY := $(shell command -v $(ROC) 2>/dev/null)
CC ?= cc
AR ?= ar
ZIG ?= zig
NODE ?= node
MACOS_SDK ?= $(shell xcrun --show-sdk-path)

BUILD_DIR := build
PLATFORM_TARGETS := platform/targets
MACOS_SYSROOT := $(PLATFORM_TARGETS)/macos-sysroot/usr/lib/libSystem.tbd
HOST_ARCH := $(shell uname -m)
ROC_CACHE_DIR ?= $(abspath $(BUILD_DIR)/roc-cache)
ZIG_CACHE_DIR := $(abspath $(BUILD_DIR)/zig-cache)

ifeq ($(HOST_ARCH),arm64)
NATIVE_TARGET := arm64mac
NATIVE_ARCH := arm64
else ifeq ($(HOST_ARCH),x86_64)
NATIVE_TARGET := x64mac
NATIVE_ARCH := x86_64
else
$(error Unsupported macOS host architecture: $(HOST_ARCH))
endif

.PHONY: all native rosetta wasm clean

all: native rosetta wasm

define RUN_AND_REPORT
	@output="$$( $(2) 2>&1 )"; process_status=$$?; \
	case "$$output" in \
		result=*) \
			result=$${output#result=}; \
			if test "$$result" = "0"; then \
				printf "%-14s OK: app returned 0\n" "$(1)"; \
			else \
				printf "%-14s BUG: app returned %s (expected 0)\n" "$(1)" "$$result"; \
			fi ;; \
		*) \
			printf "%-14s RUN FAILED: process exited %s\n" "$(1)" "$$process_status"; \
			test -z "$$output" || printf "               %s\n" "$$output" ;; \
	esac
endef

native: $(BUILD_DIR)/$(NATIVE_TARGET)-size $(BUILD_DIR)/$(NATIVE_TARGET)-speed
	@echo "== native $(NATIVE_ARCH) =="
	@echo "Expected: app returns 0"
	$(call RUN_AND_REPORT,--opt=size,$(BUILD_DIR)/$(NATIVE_TARGET)-size)
	$(call RUN_AND_REPORT,--opt=speed,$(BUILD_DIR)/$(NATIVE_TARGET)-speed)
	@echo

ifeq ($(HOST_ARCH),arm64)
rosetta: $(BUILD_DIR)/x64mac-size $(BUILD_DIR)/x64mac-speed
	@echo "== x86-64 under Rosetta =="
	@echo "Expected: app returns 0"
	$(call RUN_AND_REPORT,--opt=size,arch -x86_64 $(BUILD_DIR)/x64mac-size)
	$(call RUN_AND_REPORT,--opt=speed,arch -x86_64 $(BUILD_DIR)/x64mac-speed)
	@echo
else
rosetta:
	@echo "== x86-64 under Rosetta =="
	@echo "SKIPPED: this host is already x86-64; make native covers that target"
	@echo
endif

wasm: $(PLATFORM_TARGETS)/wasm32/host.wasm
	@mkdir -p $(BUILD_DIR)
	@echo "== wasm32 =="
	@echo "Expected: app returns 0"
	@status=0; \
		env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --opt=dev --target=wasm32 --no-cache --jobs=1 \
			--output=$(BUILD_DIR)/wasm32-dev.wasm repro.roc >$(BUILD_DIR)/wasm32-dev.build.log 2>&1 || status=$$?; \
		if test $$status -ne 0; then \
			cat $(BUILD_DIR)/wasm32-dev.build.log; \
			echo "--opt=dev     COMPILER FAILED: exit $$status"; \
			exit $$status; \
		fi
	$(call RUN_AND_REPORT,--opt=dev,$(NODE) run-wasm.js $(BUILD_DIR)/wasm32-dev.wasm)
	@for opt in size speed; do \
		status=0; \
		env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --opt=$$opt --target=wasm32 --no-cache --jobs=1 \
			--output=$(BUILD_DIR)/wasm32-$$opt.wasm repro.roc >$(BUILD_DIR)/wasm32-$$opt.build.log 2>&1 || status=$$?; \
		if test $$status -eq 0; then \
			output="$$( $(NODE) run-wasm.js $(BUILD_DIR)/wasm32-$$opt.wasm 2>&1 )"; \
			result=$${output#result=}; \
			if test "$$result" = "0"; then \
				printf "%-14s OK: app returned 0\n" "--opt=$$opt"; \
			else \
				printf "%-14s BUG: app returned %s (expected 0)\n" "--opt=$$opt" "$$result"; \
			fi; \
		elif test -s $(BUILD_DIR)/wasm32-$$opt.build.log; then \
			printf "%-14s COMPILER FAILED: exit %s; diagnostic follows\n" "--opt=$$opt" "$$status"; \
			cat $(BUILD_DIR)/wasm32-$$opt.build.log; \
		else \
			printf "%-14s COMPILER BUG: exited %s without a diagnostic or module\n" "--opt=$$opt" "$$status"; \
		fi; \
	done

$(BUILD_DIR)/arm64mac-size: repro.roc platform/main.roc $(ROC_BINARY) $(PLATFORM_TARGETS)/arm64mac/libhost.a $(MACOS_SYSROOT)
	@mkdir -p $(BUILD_DIR)
	@env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --opt=size --target=arm64mac --no-cache --jobs=1 --output=$@ repro.roc >$@.build.log 2>&1 || { cat $@.build.log; exit 1; }

$(BUILD_DIR)/arm64mac-speed: repro.roc platform/main.roc $(ROC_BINARY) $(PLATFORM_TARGETS)/arm64mac/libhost.a $(MACOS_SYSROOT)
	@mkdir -p $(BUILD_DIR)
	@env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --opt=speed --target=arm64mac --no-cache --jobs=1 --output=$@ repro.roc >$@.build.log 2>&1 || { cat $@.build.log; exit 1; }

$(BUILD_DIR)/x64mac-size: repro.roc platform/main.roc $(ROC_BINARY) $(PLATFORM_TARGETS)/x64mac/libhost.a $(MACOS_SYSROOT)
	@mkdir -p $(BUILD_DIR)
	@env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --opt=size --target=x64mac --no-cache --jobs=1 --output=$@ repro.roc >$@.build.log 2>&1 || { cat $@.build.log; exit 1; }

$(BUILD_DIR)/x64mac-speed: repro.roc platform/main.roc $(ROC_BINARY) $(PLATFORM_TARGETS)/x64mac/libhost.a $(MACOS_SYSROOT)
	@mkdir -p $(BUILD_DIR)
	@env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) build --opt=speed --target=x64mac --no-cache --jobs=1 --output=$@ repro.roc >$@.build.log 2>&1 || { cat $@.build.log; exit 1; }

$(PLATFORM_TARGETS)/arm64mac/libhost.a: platform/native-host.c
	@mkdir -p $(BUILD_DIR) $(@D)
	@$(CC) -std=c11 -arch arm64 -c $< -o $(BUILD_DIR)/native-host-arm64.o
	@$(AR) rcs $@ $(BUILD_DIR)/native-host-arm64.o

$(PLATFORM_TARGETS)/x64mac/libhost.a: platform/native-host.c
	@mkdir -p $(BUILD_DIR) $(@D)
	@$(CC) -std=c11 -arch x86_64 -c $< -o $(BUILD_DIR)/native-host-x86_64.o
	@$(AR) rcs $@ $(BUILD_DIR)/native-host-x86_64.o

$(MACOS_SYSROOT):
	@mkdir -p $(@D)
	@cp $(MACOS_SDK)/usr/lib/libSystem.tbd $@

$(PLATFORM_TARGETS)/wasm32/host.wasm: platform/wasm-host.c
	@mkdir -p $(@D) $(ZIG_CACHE_DIR)/local $(ZIG_CACHE_DIR)/global
	@env ZIG_LOCAL_CACHE_DIR=$(ZIG_CACHE_DIR)/local ZIG_GLOBAL_CACHE_DIR=$(ZIG_CACHE_DIR)/global \
		$(ZIG) cc -target wasm32-freestanding -O2 -fPIC \
		-ffunction-sections -fdata-sections -ffreestanding -fno-builtin \
		-fvisibility=default -g0 -c $< -o $@

clean:
	rm -rf $(BUILD_DIR) \
		$(PLATFORM_TARGETS)/arm64mac \
		$(PLATFORM_TARGETS)/x64mac \
		$(PLATFORM_TARGETS)/wasm32 \
		$(PLATFORM_TARGETS)/macos-sysroot
