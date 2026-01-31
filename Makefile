.PHONY: build studio

build:
	cd tools/automation/swift-cli && swift build -c release

studio: build
	tools/automation/swift-cli/.build/release/hvlien ui
