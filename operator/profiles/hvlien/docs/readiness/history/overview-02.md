# Drift Detection UX Bundle

Version: current


Includes:
- Drift report schema: shared/specs/profiles/hvlien/index/drift_report.v1.schema.json
- CLI:
  - wub drift check
  - wub drift explain <artifact>
- Helpful fix suggestions (export commands) without nagging.

Wiring:
- Add `Drift.self` to your CLI entrypoint (CliMain.swift or main.swift).
