# v9.5.0 — Racks Export (Docs & Spec)

This bundle introduces **v9.5 Asset Export Pipeline**, starting with **Ableton rack export**.

## Goal
Export real Ableton rack presets (.adg) into canonical repo paths without manual clicking.

## What ships in v9.5.0
- Declarative export job spec: `racks_export.v1.yaml`
- Receipt schema for auditability
- No automation yet (that begins in v9.5.1)

## Intended flow (next increment)
1. Read rack manifest (v6)
2. Generate per-rack apply plans
3. Automate Ableton save-preset UI (v4)
4. Verify file exists + size threshold
5. Emit `racks_export_receipt.v1.json`

## Why this matters
- Removes repetitive, painful UI work
- Makes rack artifacts first-class, verifiable outputs
- Enables voice-triggered export commands via Tahoe accessibility
