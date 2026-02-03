# v9.5.3 — Finishing Bays Export Runbook

## Version
Current: v9.5.3

## History
- (none)


This exports multiple finishing bay `.als` files into canonical repo paths.

Command:
```bash
wub assets export-finishing-bays   --spec profiles/hvlien/specs/assets/export/finishing_bays_export.v1.yaml   --overwrite   --anchors-pack specs/automation/anchors/<pack_id>
```

Behavior:
- Prompts you to open the correct bay set for each bay (keyboard-only)
- Runs Save As automation to export to the specified output_path
- Verifies file exists + size thresholds
- Emits `finishing_bays_export_receipt.v1.json`

Tahoe voice ergonomics:
- Create a phrase “export finishing bays” that runs this command.
- When prompted, say “press enter” or use voice to trigger Enter key.
