# Makefile aliases for wub workflows
# Note: This file assumes the Swift CLI builds to tools/automation/swift-cli/.build/release/wub

.PHONY: build sweep plan setup profile station studio

WUB=tools/automation/swift-cli/.build/release/wub

build:
	cd tools/automation/swift-cli && swift build -c release

sweep: build
	$(WUB) sweep

plan: build
	$(WUB) plan

setup: build
	$(WUB) setup --show-manual

profile: build
	$(WUB) profile use hvlien

station: build
	$(WUB) station status --format human

studio: build
	$(WUB) ui
