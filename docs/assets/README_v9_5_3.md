# HVLIEN v9.5.3 — Finishing Bays Export

Adds batch finishing-bay export:
- Spec file describing bays and output paths
- CLI command: `hvlien assets export-finishing-bays`
- Generates per-bay Save As plans and runs apply
- Emits a batch receipt

Note:
This is designed to be deterministic: it does NOT attempt to open/switch Ableton sets.
It prompts the operator to open the correct bay set before exporting each bay.
