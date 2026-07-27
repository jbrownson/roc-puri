ROC ?= roc
ROC_CACHE_DIR ?= $(CURDIR)/.cache/roc
ROC_SOURCES := $(wildcard *.roc)

.PHONY: fmt fmt-check check test docs clean

fmt:
	$(ROC) fmt $(ROC_SOURCES)

fmt-check:
	$(ROC) fmt --check $(ROC_SOURCES)

check: fmt-check
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) check main.roc

test:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) test main.roc

docs:
	env ROC_CACHE_DIR=$(ROC_CACHE_DIR) $(ROC) docs main.roc --output=build/docs

clean:
	rm -rf build .cache
