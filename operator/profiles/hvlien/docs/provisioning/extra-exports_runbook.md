# Extra Exports Runbook

## Version
Version: current

## History
- (none)


Exports:
- Return Space rack preset
- Return Delay rack preset
- Master safety chain preset

Command:
```bash
wub assets export-extras   --spec shared/specs/profiles/hvlien/assets/export/extra_exports.v1.yaml   --overwrite   --anchors-pack shared/specs/automation/anchors/<pack_id>
```

Notes:
- `device_name_contains` defaults to "HVLIEN". Tighten per device when you know exact rack names.
- Track names must match what appears in tracks.list (OCR) for deterministic selection.
