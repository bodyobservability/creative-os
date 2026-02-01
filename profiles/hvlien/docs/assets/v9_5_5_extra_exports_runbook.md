# v9.5.5 — Extra Exports Runbook

Exports:
- Return Space rack preset
- Return Delay rack preset
- Master safety chain preset

Command:
```bash
wub assets export-extras   --spec profiles/hvlien/specs/assets/export/extra_exports.v1.yaml   --overwrite   --anchors-pack specs/automation/anchors/<pack_id>
```

Notes:
- `device_name_contains` defaults to "HVLIEN". Tighten per device when you know exact rack names.
- Track names must match what appears in tracks.list (OCR) for deterministic selection.
