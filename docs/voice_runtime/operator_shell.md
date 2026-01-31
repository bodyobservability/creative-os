# v1.7.5 Operator Shell — Anchor Pack Auto-Detect

Enhancement: if `anchors-pack` is not configured, the operator shell will auto-detect the **newest** anchor pack directory under common locations:

- `specs/automation/anchors/`
- `tools/automation/anchors/`
- `anchors/`
- `specs/anchors/`

The detected value is stored in:
- `notes/LOCAL_CONFIG.json`

Override at any time:
```bash
hvlien ui --anchors-pack /path/to/anchor_pack
```

Shortcuts:
- r: open last receipt
- o: open last report
- f: open last run folder
- x: open last failures folder
