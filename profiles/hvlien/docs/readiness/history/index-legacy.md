# Artifact & Receipt Index

Version: v1.8.0


This bundle adds a first-pass indexer that builds:
- `checksums/index/receipt_index.v1.json`
- `checksums/index/artifact_index.v1.json`

## Commands
- `wub index build`
- `wub index status`

## What it does (v1.8.0 scope)
- Parses export specs under `profiles/hvlien/specs/assets/export/` to determine expected artifacts (paths + size thresholds).
- Scans `runs/<run_id>/` for `*receipt*.json` and indexes them.
- Scans filesystem for expected artifact paths, computes sha256 + size.
- Classifies artifact state: current | placeholder | missing | unknown

## Notes
- v1.8.0 focuses on deterministic, boring correctness.
- Drift UX ships in v1.8.1 (`wub drift check`).
