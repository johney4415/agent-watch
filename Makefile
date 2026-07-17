.PHONY: build test install

build:
	swift build

test:
	swift test

install:
	./scripts/install.sh
