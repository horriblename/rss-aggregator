
JS_OUTPUT := src/main.js

$(JS_OUTPUT): $(wildcard src/*.elm)
	elm make src/Main.elm --output $(JS_OUTPUT)

all: src/main.js

.PHONY: pidfile watch

watch:
	elm-live src/Main.elm --pushstate --start-page src/index.html -- --output main.js
