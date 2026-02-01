# Creative OS Migration Plan (Hard-Cut, Execution-Safe)

This document is the **authoritative migration spec** for transitioning this repository into a Creative Operating System. It is designed to prevent drift by:
- defining non‑negotiable contracts,
- establishing ordering constraints,
- codifying acceptance gates, and
- documenting where legacy artifacts land.

The migration **must be followed in order**. Deviations require updating this file first.

---

## Principles (Locked)

1) **Hard‑cut identity, not functionality**  
We change names, ownership, and architecture, but we do **not** strand working behavior.  
Bridge layers are allowed; compatibility layers are not.

2) **Every mutation is previewable**  
All mutating actions must have a plan view and must be classed as `automated` or `manual_required`.

3) **Observed vs desired is explicit**  
`sweep` outputs observations, `plan` outputs changes, `setup` applies safe steps only.

4) **Profiles are the only identity surface**  
Core is neutral; identity lives under `profiles/`.

5) **No hidden behavior**  
Every report explains what was seen, why it matters, and what changes are proposed.

---

## Target Identity & Structure (End State)

Final identity (hard cut):
- Repo: `studio-operator`
- CLI: `wub`
- Maintenance agent: `dub-sweeper`
- Profiles: `profiles/*` (HVLIEN becomes a profile, not the system)

Target structure:
```
core/                  # neutral runtime (observed/desired, checks, plans)
agents/                # capability modules (ableton, serum, midi, dub-sweeper)
profiles/              # identity + policy
packs/                 # opt-in creative artifacts
cli/wub/               # only human entrypoint
docs/                  # system-level docs
```

---

## Non‑Goals (v1)
- No creative decision automation
- No deep in‑DAW track manipulation
- No zero‑click promise
- No backward compatibility with hvlien‑audio‑system

---

## Phased Migration (Ordered, Gated)

### Phase 0 — Schemas & Contracts (Additive Only)
**Purpose:** establish the Creative OS vocabulary. No behavior changes.

Required schemas:
- **CheckResult**
  - `id`, `agent`, `severity`, `category`, `observed`, `expected`, `evidence`, `suggested_actions`
- **PlanStep**
  - `id`, `agent`, `type (automated|manual_required)`, `description`, `effects`, `idempotent`, `manual_reason?`
- **ObservedState / DesiredState**
  - slice‑based, with a JSONValue escape hatch
  - slices are additive; no agent may overwrite another agent’s slice
- **Profile**
  - `id`, `intents`, `policies`, `requirements`, `packs`
- **PackManifest**
  - `id`, `applies_to`, `contents`, `requires_explicit_apply`

Implementation guidance:
- Use `Codable` with `snake_case` keys (consistent with existing report lineage).
- Implement a `JSONValue` enum to keep `observed/expected` typed.

Acceptance gate:
- `swift build -c release` passes
- Existing commands (`doctor`, `ready`, `drift`) unchanged

---

### Phase 1 — Execution Bridge (Translation Layer Only)
**Purpose:** translate existing report lineage into Creative OS schemas without changing CLI behavior.

Bridge outputs:
- `DoctorReportV1` → `[CheckResult]`
- `ReadyReportV1` → `[CheckResult]` + safe `PlanStep`s
- `DriftReportV2` → `CheckResult`s + `PlanStep`s (manual_required by default)

Constraints:
- No new CLI surface in this phase.
- No deletion or modification of existing report outputs.
- Any `manual_required` PlanStep must be emitted but never executed by setup.

Acceptance gate:
- Build passes
- Translation output is deterministic given fixed input fixtures

---

### Phase 2 — Core Runtime + Agent Interface (Internal Only)
**Purpose:** formalize the OS runtime that merges state slices and produces plans.

Agent contract:
```
protocol Agent {
  var id: String
  func registerChecks(_ r: inout CheckRegistry)
  func registerPlans(_ p: inout PlanRegistry)
  func observeState() throws -> ObservedStateSlice
}
```

Runtime responsibilities:
- merge observed slices
- apply profile policy → desired state
- diff observed vs desired
- emit `sweep` + `plan` structures

Acceptance gate:
- Build passes
- NullAgent shows end‑to‑end flow

---

### Phase 3 — `wub` CLI (Parity First, No Deletions)
**Purpose:** add `wub` without removing `hvlien`.

Implementation constraints:
- Shared library target (`StudioCore`) with two executables (`hvlien`, `wub`)
- `wub` uses bridge/runtime outputs

Minimum parity checklist:
- `wub sweep`
- `wub plan`
- `wub setup`
- `wub profile use`

Acceptance gate:
- Output is JSON‑capable and human‑readable:
  - JSON via `--json` (or structured default)
  - Human output derived from the same data structure (no parallel logic)
- `wub sweep` facts align with current `doctor`/`ready`/`drift` reports

---

### Phase 4 — Profile + Pack Manifests + Selection Store
**Purpose:** move identity to profiles, formalize packs.

Requirements:
- `profiles/hvlien.profile.yaml`
- `packs/hvlien-defaults/pack.yaml`
- Profile selection stored in repo‑local config (e.g., `notes/WUB_CONFIG.json`)

Acceptance gate:
- `wub profile use hvlien` persists selection
- `wub sweep` loads profile policies

---

### Phase 5 — Asset + Spec Migration Mapping (Explicit)
**Purpose:** prevent loss of accumulated assets and specs.

Mapping rules (codified):
| Legacy artifact | New home |
| --- | --- |
| specs | agent checks |
| receipts | observed state snapshots |
| checksums | plan validation inputs |
| anchor packs | profile packs |
| automation plans | agent PlanSteps |

Acceptance gate:
- Mapping table exists in docs + code
- Runtime references mapping definitions (at minimum for validation)

---

### Phase 6 — Testing & CI
**Purpose:** ensure migration is verifiable.

Tests:
- Snapshot tests for `wub sweep` and `wub plan`
- Unit tests for severity mapping + policy diff

Acceptance gate:
- `swift test` green
- One manual “fresh machine” smoke checklist per release

---

### Phase 7 — Identity Hard Cut (Final)
**Purpose:** rename and remove legacy surface after parity.

Required actions:
- Repo renamed to `studio-operator`
- Remove `hvlien` CLI
- Remove `doctor` language
- README rewritten with Creative OS framing
- HVLIEN exists only as a profile

Acceptance gate:
- `wub` is sole entrypoint
- End‑to‑end workflows pass

---

## Safety Contracts (Enforced)

1) **No destructive ops in v1**
2) **All mutating commands must be previewable**
3) **Every risky step must be labeled `manual_required`**
4) **Gating uses station status before mutations**

If these rules conflict with implementation, update this document before changing code.

---

## Drift Prevention (Governance)

This document is authoritative. Changes must:
- update this file first,
- include acceptance gates,
- be implemented as a PR phase.

Any shortcut must be documented as a deliberate exception.

---

## Migration Completion Statement

Migration is complete when all are true:
- `wub profile use hvlien`
- `wub sweep`
- `wub plan`
- `wub setup`
- No domain logic in CLI
- No identity in core
- Agents contain all capabilities
- No legacy report types are consumed by `wub`

At that point:

“This is not an audio tool.  
It’s a Creative OS.  
`wub` is how it is operated.  
Profiles are where creators live.  
Agents are how it grows.”
