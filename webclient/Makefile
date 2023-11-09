PREFIX ?= /usr/local
SHARE_DIR ?= $(PREFIX)/share

JS_OUTPUT := deploy/main.js
INSTALL_DIR := $(SHARE_DIR)/rss-aggre-client

.PHONY: watch release install

release: $(JS_OUTPUT) deploy/index.html

install: $(JS_OUTPUT) deploy/index.html
	mkdir -p $(INSTALL_DIR)
	cp $^ $(INSTALL_DIR)

deploy/index.html:
	mkdir -p deploy
	cp index.html $@

$(JS_OUTPUT): $(wildcard src/*.elm)
	mkdir -p deploy
	elm make src/Main.elm --optimize --output=elm.js
	uglifyjs elm.js --compress 'pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle --output $(JS_OUTPUT)
	@echo "Compiled size: $$(wc elm.js -c) bytes (elm.js)"
	@echo "Minified size: $$(wc $(JS_OUTPUT) -c) bytes ($(JS_OUTPUT))"
	@echo "Gzipped size: $$(gzip $(JS_OUTPUT) -c | wc -c) bytes"

watch:
	elm-live --pushstate --start-page index.html src/Main.elm -- --output main.js
