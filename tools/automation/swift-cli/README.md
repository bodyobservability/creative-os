# HVLIEN CLI (v2 bundle)

Build:
  swift build -c release

A0 (safe-mode manual inventory):
  .build/release/hvlien a0 --spec specs/automation/examples/HVLIEN_RECORDING_BAY_v1.yaml --interactive

Resolve-only:
  .build/release/hvlien resolve --spec <spec.yaml> --inventory <inventory.v1.json> --controllers <controllers_inventory.v1.json> --interactive

Note: This v2 bundle ships A0 capture in **safe manual mode** (paste lines) to avoid automating Ableton UI.
You can swap in ScreenCaptureKit+Vision OCR later without changing schemas/resolvers.

A0 now captures the Ableton Browser results list automatically via ScreenCaptureKit + Vision OCR.
Configure the capture region in tools/automation/swift-cli/config/regions.v1.json.
