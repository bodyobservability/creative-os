# Roadmap

This document is the canonical roadmap for Studio Operator / Creative OS.
It consolidates the roadmap content from the repo root README and the
Creative OS refactor plan.

## Scope

- Creative OS kernel: safety, execution model, governance
- Studio Operator roadmap: releases, milestones, and operator examples

## Creative OS kernel (safety-first refactor)

The kernel roadmap is tracked as a staged PR sequence in
`CREATIVE_OS_REFACTOR.md`. That plan is the authoritative reference for
execution safety, gating, and schema governance.

### Kernel refactor sequence (summary)

1. PR 0 — Safety harness (tests + fixtures)
2. PR 1 — Permissioned execution model (deny-by-default)
3. PR 2 — Action catalog + config contracts
4. PR 3 — Setup receipts (schema-first)
5. PR 4 — Agent modularization (move-only)
6. PR 5 — Service config consolidation
7. PR 6 — Station gating consolidation
8. PR 7 — Agent-owned checks + deterministic merges
9. PR 8 — Pluggable service executor
10. PR 9 — CI governance (schema + checksum validation)
11. PR 10 — Actuation subsystem boundary prep

Status: PR 0–10 complete as of February 3, 2026. Follow-up hardening (PR7 checks + PR9 governance + allowlist centralization) completed February 3, 2026.

## Versioning + Release Model (Proposal)

- **Milestone releases** use `vX.Y` tags (not time-boxed).
- **X (major)** = identity or contract shifts (CLI surface, schemas, or core guarantees).
- **Y (minor)** = new intelligence or certification capabilities that do not break contracts.
- **Patch** = fixes, stability, performance, and doc-only updates.
- **Profiles and packs version independently** from core (semantic versions per profile/pack).
- Each release ships with:
  - `wub state-sweep/state-plan/state-setup` snapshot tests
  - a fresh-machine smoke checklist entry
  - a short release note in `docs/release/`

## Milestones (Intelligence + Guarantees)

### v1.9 — Cross-Rack Intelligence (bass-focused)

- Analyze interactions between exported artifacts:
  - Sub ↔ BassLead mono/phase stability
  - Return FX low-end smearing
  - Transient collisions (kick/sub/bass)
- Output ranked recommendations and proposed patches (never auto-applied):
  - “tighten Motion high bound”
  - “reduce Width max for sub safety”
- Deliverables:
  - `wub analyze cross-rack` report + recommendations
  - PR-ready patch artifacts (manual apply only)

### v2.0 — Constrained Auto-Tuning Proposals

- Generate proposed profile patches from measured receipts under strict constraints:
  - calibrated sweeps, regression diffs, and release gates
- Output PR-friendly patch artifacts; promotion remains gated by certify/release pipeline.
- Deliverables:
  - `wub propose tune --profile <id>` (patch + diff + evidence)

### v2.1 — Set-Level Intelligence (optional, heavier)

- Scene-to-scene energy / contrast analysis on exported performance sets.
- Suggested macro snapshots per scene (still discrete and bounded).
- Deliverables:
  - `wub analyze set` (scene recommendations + snapshot candidates)

### v2.2 — Performance Guarantees (optional)

- Live-set safety certification across scenes:
  - no clipping, no silence, no runaway macros
- Emit a “tour-ready” style receipt.
- Deliverables:
  - `wub certify performance` (receipt + pass/fail)

## Voice-as-Operator (Examples)

- “export everything”
- “check drift”
- “build index”
- “certify station”
- “run cross-rack analysis”
