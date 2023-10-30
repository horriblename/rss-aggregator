
JS_OUTPUT := src/main.js

$(JS_OUTPUT): $(wildcard src/*.elm)
	elm make src/Main.elm --output $(JS_OUTPUT)

all: src/main.js

.PHONY: watch

watch:
	elm-live --pushstate --start-page index.html src/Main.elm -- --output main.js
