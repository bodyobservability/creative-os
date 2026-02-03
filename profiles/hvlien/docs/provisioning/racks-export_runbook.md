# Racks Export Automation Runbook

## Version
Version: current

## History
- history/racks-export.md


## Goal
Export real Ableton rack presets (`.adg`) into your repo folder with minimal/no UI clicking.

## Command (planned)
```bash
wub assets export-racks   --manifest profiles/hvlien/specs/library/racks/rack_pack_manifest.v1.json   --out packs/hvlien-defaults/ableton/racks/BASS_RACKS_v1.0   --anchors-pack specs/automation/anchors/<pack_id>   --overwrite ask   --interactive
```

## Preconditions
- Ableton is frontmost
- Rack devices are visible in `device.chain` and OCR-readable
- macOS save sheet supports **Cmd+Shift+G** (Go to Folder)
- Region configured: `os.file_dialog.filename_field`
- If using anchors: `macos.open_dialog.filename_field` anchor captured

## Output
- plans: `runs/<run_id>/plans/export_rack_*.plan.v1.json`
- receipt: `runs/<run_id>/racks_export_receipt.v1.json`
- exported racks: `packs/hvlien-defaults/ableton/racks/BASS_RACKS_v1.0/*.adg`

## Debug ladder
1) Dry run to confirm target filenames and tracks
2) Run with overwrite=never to avoid losing existing exports
3) If rack selection fails: use a more stable OCR token than full display_name
4) If folder navigation fails: ensure save sheet is active and Cmd+Shift+G is supported

## Voice ergonomics (Tahoe)
Create a Voice Control command “export racks” that runs a KM macro which executes:
`wub assets export-racks --overwrite ask --interactive`
