# Wub CLI

Build:
  swift build -c release

This repo is already wired; historical toolchain zips are not included.

## Core commands

Creative OS state:
  .build/release/wub sweep
  .build/release/wub plan --json
  .build/release/wub setup --show-manual

A0 (safe‑mode manual inventory):
  .build/release/wub a0 --spec profiles/hvlien/specs/automation/examples/HVLIEN_RECORDING_BAY_v1.yaml --interactive

Resolve‑only:
  .build/release/wub resolve --spec <spec.yaml> --inventory <inventory.v1.json> --controllers <controllers_inventory.v1.json> --interactive

Plan (legacy):
  .build/release/wub plan-legacy --spec <spec.yaml> --resolve <resolve_report.json>

Apply:
  .build/release/wub apply --plan runs/<run_id>/plan.v1.json --teensy /dev/cu.usbmodemXXXX --evidence=fail --interactive

DubSweeper (station readiness, legacy):
  .build/release/wub sweep-legacy --modal-test detect --allow-ocr-fallback

## UI automation utilities

calibrate‑regions:
  wub calibrate-regions

capture‑anchor:
  wub capture-anchor --region browser.search --frames 5 --interval-ms 200

validate‑anchors (OpenCV build required):
  wub validate-anchors --pack specs/automation/anchors/ableton12_3_macos_default_5k_morespace

OpenCV build guide:
  tools/automation/swift-cli/docs/OPENCV_BUILD.md

## Index + drift

Index build/status:
  wub index build
  wub index status

Drift check/plan/fix:
  wub drift check --anchors-pack-hint specs/automation/anchors/<pack_id>
  wub drift plan  --anchors-pack-hint specs/automation/anchors/<pack_id>
  wub drift fix   --anchors-pack-hint specs/automation/anchors/<pack_id> --dry-run

## Automation workflows (selected)

Voice compile handshake:
  wub voice run --script <script.yaml> --abi <abi.yaml> --anchors-pack <pack> --macro-ocr

Rack install/verify:
  wub rack install --manifest profiles/hvlien/specs/library/racks/rack_pack_manifest.v1.json --macro-region rack.macros --anchors-pack <pack>
  wub rack verify  --manifest profiles/hvlien/specs/library/racks/rack_pack_manifest.v1.json --macro-region rack.macros --anchors-pack <pack>

Sonic sweep + certify:
  wub sonic sweep-compile --macro Width --positions 0,0.25,0.5,0.75,1 --export-dir /tmp/hvlien_exports --midi-dest IAC --cc 21
  wub sonic sweep --macro Width --dir /tmp/hvlien_exports
  wub sonic certify --baseline <baseline.json> --sweep <sweep_receipt.json> --rack-id <rack_id> --profile-id <profile_id> --macro Width

Station certify:
  wub station certify --profile bass_v1

Operator shell:
  wub ui --anchors-pack specs/automation/anchors/<pack_id>

Asset export:
  wub assets export-all --anchors-pack specs/automation/anchors/<pack_id> --overwrite
