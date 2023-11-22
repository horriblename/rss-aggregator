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

DOCKER_CMD ?= docker

PREFIX := /usr/local
BIN_DIR := $(PREFIX)/bin
BIN_NAME := $(BIN_DIR)/rss-aggre

build/server: $(shell find . -name '*.go')
	mkdir -p build
	go build -o $@

all: build/server

install: all
	install -D --mode=755 --no-target-directory build/server $(BIN_NAME)

# Deployment
# ----------
.PHONY: push-goose push-rss-aggre push-images

push-images: push-goose push-rss-aggre

push-goose:
	nix build .\#gooseImageStream
	./result | $(DOCKER_CMD) load
	$(DOCKER_CMD) push horriblename/goose:latest

push-rss-aggre:
	nix build .\#dockerImage
	./result | $(DOCKER_CMD) load
	$(DOCKER_CMD) push horriblename/rss-aggre:latest

# Development niceties
# --------------------

.PHONY: stop watch all test compose compose-rebuild

pidfile: build/server
	$(MAKE) stop
	env PORT=8080 $< & echo $$! > pidfile

stop:
	if [ -f pidfile ]; then kill "$$(cat pidfile)"; rm pidfile; fi

watch:
	$(MAKE) stop
	while true; do $(MAKE) --silent pidfile; sleep 2; done

test: pidfile
	fennel tests/api/init.fnl

compose:
	cd deploy && $(DOCKER_CMD)-compose up
	
compose-rebuild:
	cd deploy && ./up.sh
