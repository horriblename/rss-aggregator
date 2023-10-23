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

backend/server: $(shell find backend -name '*.go')
	go build -o $@ ./backend/

all: backend/server

install: all
	install -D --mode=755 backend/server $(BIN_DIR)

.PHONY: stop watch all

# Development niceties
# --------------------

pidfile: backend/server
	$(MAKE) stop
	$< & echo $$! > pidfile

stop:
	if [ -f pidfile ]; then kill "$$(cat pidfile)"; rm pidfile; fi

watch:
	$(MAKE) stop
	watch $(MAKE) pidfile
