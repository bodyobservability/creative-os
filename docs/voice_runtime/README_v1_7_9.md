# HVLIEN v1.7.9 — Operator Shell Wizard Integrated

This bundle integrates a **first-run wizard** into the current Operator Shell (v1.7.8 lineage) without removing any existing capabilities.

## Adds
- One-time wizard on first `hvlien ui` launch:
  - Build CLI
  - Doctor
  - Index build

## Persists
- `notes/LOCAL_CONFIG.json` now includes:
  - `anchorsPack`
  - `firstRunCompleted`

## Wiring
No new commands: still `hvlien ui`.
Apply and rebuild.
