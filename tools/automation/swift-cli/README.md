# HVLIEN CLI

Build:
  swift build -c release

This repo is already wired; historical toolchain zips are not included.

## Core commands

A0 (safe‑mode manual inventory):
  .build/release/hvlien a0 --spec specs/automation/examples/HVLIEN_RECORDING_BAY_v1.yaml --interactive

Resolve‑only:
  .build/release/hvlien resolve --spec <spec.yaml> --inventory <inventory.v1.json> --controllers <controllers_inventory.v1.json> --interactive

Plan:
  .build/release/hvlien plan --spec <spec.yaml> --resolve <resolve_report.json>

Apply:
  .build/release/hvlien apply --plan runs/<run_id>/plan.v1.json --teensy /dev/cu.usbmodemXXXX --evidence=fail --interactive

Doctor (station readiness):
  .build/release/hvlien doctor --modal-test detect --allow-ocr-fallback

## UI automation utilities

calibrate‑regions:
  hvlien calibrate-regions

capture‑anchor:
  hvlien capture-anchor --region browser.search --frames 5 --interval-ms 200

validate‑anchors (OpenCV build required):
  hvlien validate-anchors --pack specs/automation/anchors/ableton12_3_macos_default_5k_morespace

OpenCV build guide:
  tools/automation/swift-cli/docs/OPENCV_BUILD.md

## Index + drift (v1.8)

Index build/status:
  hvlien index build
  hvlien index status

Drift check/plan/fix:
  hvlien drift check --anchors-pack-hint specs/automation/anchors/<pack_id>
  hvlien drift plan  --anchors-pack-hint specs/automation/anchors/<pack_id>
  hvlien drift fix   --anchors-pack-hint specs/automation/anchors/<pack_id> --dry-run

## Automation workflows (selected)

Voice compile handshake:
  hvlien voice run --script <script.yaml> --abi <abi.yaml> --anchors-pack <pack> --macro-ocr

Rack install/verify:
  hvlien rack install --manifest specs/library/racks/rack_pack_manifest.v1.json --macro-region rack.macros --anchors-pack <pack>
  hvlien rack verify  --manifest specs/library/racks/rack_pack_manifest.v1.json --macro-region rack.macros --anchors-pack <pack>

Sonic sweep + certify:
  hvlien sonic sweep-compile --macro Width --positions 0,0.25,0.5,0.75,1 --export-dir /tmp/hvlien_exports --midi-dest IAC --cc 21
  hvlien sonic sweep --macro Width --dir /tmp/hvlien_exports
  hvlien sonic certify --baseline <baseline.json> --sweep <sweep_receipt.json> --rack-id <rack_id> --profile-id <profile_id> --macro Width

Station certify:
  hvlien station certify --profile bass_v1

Operator shell:
  hvlien ui --anchors-pack specs/automation/anchors/<pack_id>

Asset export:
  hvlien assets export-all --anchors-pack specs/automation/anchors/<pack_id> --overwrite
