# v9.5.4 — Serum Base Patch Export Runbook

## Goal
Export the canonical Serum base patch into:
`library/serum/HVLIEN_SERUM_BASE_v1.0.fxp`

## Command
```bash
hvlien assets export-serum-base   --out library/serum/HVLIEN_SERUM_BASE_v1.0.fxp   --anchors-pack specs/automation/anchors/<pack_id>   --overwrite
```

## Preconditions
- Ableton open; Serum device present in the device chain
- v4.3 Serum automation anchors captured:
  - serum.window.signature
  - serum.menu_preset
  - serum.menu_save_preset
- macOS save sheet:
  - Cmd+Shift+G works
  - filename field anchor/region available

## Plan used
This command runs:
`specs/assets/plans/serum_base_export.plan.v1.json`

## Outputs
- receipt: runs/<run_id>/serum_base_export_receipt.v1.json
- file: library/serum/HVLIEN_SERUM_BASE_v1.0.fxp

## Debug
If it fails, check:
- `runs/<run_id>/trace.v1.json` and failures screenshots from apply
- anchor pack contains the required Serum anchors
- `hvlien midi list` not relevant here; this is UI automation + save dialog
