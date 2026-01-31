# v9.5.2 — Performance Set Export Runbook

## Goal
Replace placeholder:
`ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als`
with a real exported Ableton performance set.

## Command
```bash
hvlien assets export-performance-set   --out ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als   --overwrite   --anchors-pack specs/automation/anchors/<pack_id>
```

## Preconditions
- The correct Ableton performance set is currently open (frontmost)
- macOS save sheet supports Cmd+Shift+G (Go to Folder)
- `os.file_dialog.filename_field` region exists
- (optional) `macos.open_dialog.filename_field` anchor exists

## Outputs
- plan: runs/<run_id>/plans/export_performance_set.plan.v1.json
- receipt: runs/<run_id>/performance_set_export_receipt.v1.json
- file: ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als

## Tahoe Voice ergonomics
Create a Voice Control phrase “export performance set” that runs the CLI command.
