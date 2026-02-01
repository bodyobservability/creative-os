# Makefile aliases for HVLIEN operator workflows
# Note: This file assumes the Swift CLI builds to tools/automation/swift-cli/.build/release/hvlien

.PHONY: build studio doctor export certify index drift ready

HVLIEN=tools/automation/swift-cli/.build/release/hvlien
ANCHORS?=specs/automation/anchors/ableton12_3_macos_default_2560x1440

build:
	cd tools/automation/swift-cli && swift build -c release

studio: build
	$(HVLIEN) ui

doctor: build
	$(HVLIEN) doctor --modal-test detect --allow-ocr-fallback

index: build
	$(HVLIEN) index build

drift: build
	$(HVLIEN) drift check --anchors-pack-hint $(ANCHORS)

export: build
	$(HVLIEN) assets export-all --anchors-pack $(ANCHORS) --overwrite

certify: build
	$(HVLIEN) station certify

ready: build
	$(HVLIEN) ready --anchors-pack-hint $(ANCHORS)
