PREFIX ?= /usr/local
SHARE_DIR ?= $(PREFIX)/share

INSTALL_DIR := $(SHARE_DIR)/rss-aggre-client
BUILD_DIR := build
JS_OUTPUT := $(BUILD_DIR)/Main.js
HTML_OUTPUT := index.html

.PHONY: watch release install clean

release: $(JS_OUTPUT) $(HTML_OUTPUT)

install: $(JS_OUTPUT) $(HTML_OUTPUT)
	mkdir -p $(INSTALL_DIR)
	cp $^ $(INSTALL_DIR)

clean:
	rm -rf Main.js build/

$(JS_OUTPUT): $(wildcard src/*.elm)
	mkdir -p $(BUILD_DIR)
	elm make src/Main.elm --optimize --output=elm.js
	uglifyjs elm.js --compress 'pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output $(JS_OUTPUT)
	@echo "Compiled size: $$(wc elm.js -c) bytes (elm.js)"
	@echo "Minified size: $$(wc $(JS_OUTPUT) -c) bytes ($(JS_OUTPUT))"
	@echo "Gzipped size: $$(gzip $(JS_OUTPUT) -c | wc -c) bytes"

watch:
	elm-live --pushstate --start-page index.html src/Main.elm -- --output Main.js
