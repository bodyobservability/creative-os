# HVLIEN legacy — Racks Export Automation (Draft Implementation Bundle)

Adds:
- Swift CLI: `wub assets export-racks`
- Plan generator: per-rack v4 apply plans
- Receipt emission: racks_export_receipt.v1.json
- Runbook

Wiring:
- Add `Assets.self` to your CLI entrypoint (CliMain.swift or main.swift).
