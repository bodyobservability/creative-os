# Roadmap

This document is the canonical roadmap for Studio Operator / Creative OS.
It consolidates the roadmap content from the repo root README and the
Creative OS refactor plan.

## Scope

- Creative OS kernel: safety, execution model, governance
- Studio Operator roadmap: releases, milestones, and operator examples

## Creative OS kernel (safety-first refactor)

The kernel roadmap is tracked below as a staged PR sequence. Execution
safety, gating, and schema governance are now enforced in code and CI.

### Kernel refactor sequence (completed)

Completed PR sequence: PR 0 safety harness; PR 1 permissioned execution; PR 2 action catalog + config contracts; PR 3 setup receipts; PR 4 agent modularization; PR 5 service config consolidation; PR 6 station gating; PR 7 agent-owned checks + deterministic merges; PR 8 pluggable executor; PR 9 CI governance; PR 10 actuation boundary prep.

Status: PR 0–10 complete as of February 3, 2026. Follow-up hardening (PR7 checks + PR9 governance + allowlist centralization) completed February 3, 2026. CI split into governance + swift-tests workflows February 3, 2026.

## Release Model (Creative OS stance)

- **Milestones are named, not versioned.** Avoid `vX.Y` in doc/spec filenames and headings.
- **If external release tags exist**, keep them in release notes only; do not embed them in docs/specs.
- **Profiles and packs** may carry semantic versions for compatibility, but the canonical docs use `Version: current`.
- Each milestone ships with:
  - `wub state-sweep/state-plan/state-setup` snapshot tests
  - a fresh-machine smoke checklist entry
  - a short release note in `docs/release/`

## Milestones (Intelligence + Guarantees)

### Cross-Rack Intelligence (bass-focused)

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

### Constrained Auto-Tuning Proposals

- Generate proposed profile patches from measured receipts under strict constraints:
  - calibrated sweeps, regression diffs, and release gates
- Output PR-friendly patch artifacts; promotion remains gated by certify/release pipeline.
- Deliverables:
  - `wub propose tune --profile <id>` (patch + diff + evidence)

### Set-Level Intelligence (optional, heavier)

- Scene-to-scene energy / contrast analysis on exported performance sets.
- Suggested macro snapshots per scene (still discrete and bounded).
- Deliverables:
  - `wub analyze set` (scene recommendations + snapshot candidates)

### Performance Guarantees (optional)

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
