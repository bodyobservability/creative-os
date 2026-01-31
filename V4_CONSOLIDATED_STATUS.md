Note: Superseded by the v4–v8.7 toolchain bundle; kept for historical reference.

# HVLIEN Automation Bundle v4.2 (Consolidated)

This bundle consolidates v3 (inventory+resolve) with v4.2 (UI actuation):
- `hvlien plan` emits plan.v1.json from spec + resolve_report
- `hvlien apply` executes plan using OCR-bbox clicking (double-click Browser result)
  - Actuation backend: Teensy (serial) preferred; CGEvent fallback supported
  - Evidence output: --evidence=none|fail|all
  - Outputs: receipt.v1.json, trace.v1.json, evidence/, failures/
- Calibration utilities:
  - capture-anchor
  - validate-anchors (OpenCV anchor matching via ObjC++ bridge)
  - calibrate-regions

Not included (next v4.3+):
- Plugin window open + Serum preset load
- Browser pagination/scroll automation
