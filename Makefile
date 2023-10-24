# Basic Usage:
# ============
#
# Build and install:
#
#     make && make install
#
# Watch (restart on change):
#
#     make watch
#

PREFIX := /usr/local
BIN_DIR := $(PREFIX)/bin
BIN_NAME := $(BIN_DIR)/rss-aggre

build/server: $(shell find . -name '*.go')
	mkdir -p build
	go build -o $@

all: build/server

install: all
	install -D --mode=755 --no-target-directory build/server $(BIN_NAME)

.PHONY: stop watch all

# Development niceties
# --------------------

pidfile: build/server
	$(MAKE) stop
	$< & echo $$! > pidfile

stop:
	if [ -f pidfile ]; then kill "$$(cat pidfile)"; rm pidfile; fi

watch:
	$(MAKE) stop
	watch $(MAKE) pidfile
