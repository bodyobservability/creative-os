# Studio Operator

Creative OS for studio workflows. The CLI is `wub`, and identity lives in profiles.

## Quickstart

Build the CLI:
```bash
cd tools/automation/swift-cli
swift build -c release
```

Run the core commands:
```bash
tools/automation/swift-cli/.build/release/wub sweep
tools/automation/swift-cli/.build/release/wub plan --json
tools/automation/swift-cli/.build/release/wub setup --show-manual
```

Legacy automation commands:
```bash
tools/automation/swift-cli/.build/release/wub sweep
```

Select a profile:
```bash
tools/automation/swift-cli/.build/release/wub profile use hvlien
```

Check station state:
```bash
tools/automation/swift-cli/.build/release/wub station status --format json --no-write-report
```

## Profiles and packs

- Profiles live in `profiles/` (for example `profiles/hvlien.profile.yaml`).
- Packs live in `packs/` and can be attached to a profile.
- Active selection is stored in `notes/WUB_CONFIG.json`.

## Repo layout (current)

- `tools/automation/` — Swift CLI and automation tooling
- `profiles/` — identity and policy
- `packs/` — optional creative artifacts
- `specs/` — specs, schemas, and runbooks
- `docs/` — system docs and runbooks
- `notes/` — operational notes and checklists

## Status

Migration milestones have been completed; the current architecture is documented throughout `docs/` and `profiles/`.

## Roadmap (Studio Operator)

### Versioning + Release Model (Proposal)
- **Milestone releases** use `vX.Y` tags (not time-boxed).
- **X (major)** = identity or contract shifts (CLI surface, schemas, or core guarantees).
- **Y (minor)** = new intelligence or certification capabilities that do not break contracts.
- **Patch** = fixes, stability, performance, and doc-only updates.
- **Profiles and packs version independently** from core (semantic versions per profile/pack).
- Each release ships with:
  - `wub state-sweep/state-plan/state-setup` snapshot tests
  - a fresh-machine smoke checklist entry
  - a short release note in `docs/release/`

### Milestones (Intelligence + Guarantees)

#### v1.9 — Cross-Rack Intelligence (bass-focused)
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

#### v2.0 — Constrained Auto-Tuning Proposals
- Generate proposed profile patches from measured receipts under strict constraints:
  - calibrated sweeps, regression diffs, and release gates
- Output PR-friendly patch artifacts; promotion remains gated by certify/release pipeline.
- Deliverables:
  - `wub propose tune --profile <id>` (patch + diff + evidence)

#### v2.1 — Set-Level Intelligence (optional, heavier)
- Scene-to-scene energy / contrast analysis on exported performance sets.
- Suggested macro snapshots per scene (still discrete and bounded).
- Deliverables:
  - `wub analyze set` (scene recommendations + snapshot candidates)

#### v2.2 — Performance Guarantees (optional)
- Live-set safety certification across scenes:
  - no clipping, no silence, no runaway macros
- Emit a “tour-ready” style receipt.
- Deliverables:
  - `wub certify performance` (receipt + pass/fail)

### Voice-as-Operator (Examples)
- “export everything”
- “check drift”
- “build index”
- “certify station”
- “run cross-rack analysis”
