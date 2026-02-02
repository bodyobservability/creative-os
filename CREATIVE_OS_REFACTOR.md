# Creative OS Refactor Plan

> ⚠️ EXECUTION MODEL NOTE (SAFETY-FIRST)
>
> During this refactor, execution is treated as **actuation**: it must be explicit, inspectable, and constrained.
> The default posture is **deny-by-default** with **dry-run** as the primary UX.
>
> Until the Action Catalog + schemas land (PR 2) and gating is consolidated (PR 6),
> `state-setup` should only execute a **small, explicit allowlist** of actions that are
> safe to re-run and/or read-only. Everything else remains visible in plans but non-executable.

Below is a comprehensive, safe diff plan designed to keep the repo continuously working while moving decisively toward the Creative OS target. It is structured as a PR series with:

- Goal
- Files touched (exact paths)
- Key changes
- Acceptance criteria (what must still work)
- Rollback strategy

This plan is intentionally surgical: small deltas, measurable outcomes, and minimal cross-cutting change per PR.

## Guiding invariants (non-negotiable)

These invariants should be true after every PR:

1. `make test` / `.github/workflows/swift-tests.yml` remains green.
2. `wub state-sweep`, `wub state-plan`, and `wub state-setup` still run.
3. No PR mixes file moves + behavior changes unless explicitly called out.
4. Creative OS “setup” only executes steps that are explicitly safe to execute (station gating stays enforced at the right place).
5. Every automated step produces or references a receipt (or explicitly documents why it cannot yet).

---

## PR 0 — Add refactor safety harness (tests + fixtures)

**Goal:** Create a safety net so refactors don’t silently degrade behavior.

**Files touched:**

- `tools/automation/swift-cli/Package.swift` (test target if missing)
- `tools/automation/swift-cli/Tests/StudioCoreTests/*` (new)
- `tools/automation/swift-cli/Sources/StudioCore/WubRuntime.swift` (minor: injectable paths)
- `tools/automation/swift-cli/Sources/StudioCore/JSONIO.swift` (if needed for tests)

**Key changes:**

- Add a small suite of tests that:
  - Constructs a `WubContext` with a temp repo layout (profiles + notes config).
  - Verifies `CreativeOS.Runtime.plan()` returns deterministic ordering.
  - Verifies `ServiceExecutor.execute(step:)` rejects unsupported action IDs.
- Add minimal fixture content for:
  - `profiles/*.profile.yaml`
  - `notes/WUB_CONFIG.json`
- PR 0 progress:
  - [x] Add injectable Wub store root for tests (no behavior change).
  - [x] Add minimal fixtures for profiles + WUB_CONFIG.
  - [x] Test WubContext plan report ordering is deterministic.
  - [x] Test ServiceExecutor rejects unsupported action IDs.

**Acceptance criteria:**

- CI green.
- Tests prove:
  - plan ordering stable (`(agent,id)` sort).
  - `ServiceExecutor.ExecutionError.unsupportedAction` triggers correctly.

**Rollback:** revert test folder + any injection hooks.

---

## PR 1 — Permissioned execution model (deny-by-default)

Right now: many steps include an `actionRef` but are still type: `.manualRequired`, so `state-setup` won’t execute them.
We want Creative OS setup to become real, but **without** implicitly executing new actions just because an `actionRef` exists.

**Goal:** Make execution explicit and policy-gated:
- `actionRef` makes a step *addressable*, not automatically executable.
- `state-setup` executes only an explicit allowlist of actions (initially hardcoded, later owned by the Action Catalog).

**Files touched:**

- `tools/automation/swift-cli/Sources/StudioCore/CreativeOSModels.swift`
- `tools/automation/swift-cli/Sources/StudioCore/WubAgents.swift`
- `tools/automation/swift-cli/Sources/StudioCore/WubCli.swift`

**Key changes:**

1. Update `WubStateSetup` / `WubSetup` selection logic from:

```swift
let automated = report.steps.filter { $0.type == .automated }
```

to:

- Treat steps as *eligible* if `step.actionRef != nil`.
- Treat steps as *executable* in `state-setup` only if:
  - action ID is in an explicit **allowlist** for this command/context, AND
  - `ServiceExecutor` supports it.

> The allowlist is intentionally small until PR 2 (catalog + schemas) and PR 6 (gating consolidation).
> The default for unknown/unclassified actions is **do not execute**.

2. Update agents that already include `actionRef` (e.g. `SweeperAgent`, `DriftAgent`, `ReadyAgent`, `StationAgent`, `AssetsAgent`, etc.) so their steps are type: `.automated` (or new rule makes that irrelevant).
3. Keep `.process` effects only as optional “debug hints” — never executed by `state-setup`.

PR 1 progress:
- [x] Gate execution by allowlist + ServiceExecutor support for actionRef steps.
- [x] Default `state-setup`/`setup` to dry-run; add explicit `--apply`.
- [x] Ensure `state-setup` never executes `.process` effects.
- [ ] Update agent plan steps with `actionRef` to use `.automated`.

**Acceptance criteria:**

- `wub state-setup` defaults to **dry-run** output (prints what would run and why others are skipped).
- Execution requires explicit opt-in (e.g., `--apply`).
- Only allowlisted actions can execute; all other actions remain visible but non-executable.
- `.process` effects are not executed by `state-setup` under any circumstances.
- At least one allowlisted action successfully executes via `ServiceExecutor.execute(step:)`.

**Rollback:** revert selection logic + revert step type changes.

---

## PR 2 — Standardize config payload keys across agents (remove drift & edge bugs)

Right now configs are constructed in `WubAgents.swift` via `configEffect(...)` with ad-hoc keys. `ServiceExecutor` expects very specific keys.

**Goal:** Make config effects consistent and centrally defined so agents can’t “almost match” what services expect.

**Files touched:**

- `tools/automation/swift-cli/Sources/StudioCore/WubAgents.swift`
- `tools/automation/swift-cli/Sources/StudioCore/ServiceExecutor.swift`
- New: `tools/automation/swift-cli/Sources/StudioCore/CreativeOSActionCatalog.swift`

**Key changes:**

- Create `CreativeOSActionCatalog`:
  - defines action IDs (`"sweeper.run"`, `"drift.check"`, …)
  - defines canonical config keys per action (`anchors_pack`, `runs_dir`, etc.)
  - provides helpers to build a config effect (no more hand-built dictionaries sprinkled around)
- Update each agent’s plan step builder to call catalog helpers.

**Acceptance criteria:**

- Unit test: for each action id in `ServiceExecutor`, there is a corresponding catalog entry.
- `state-setup` executes without “missing config” errors for default plan.

**Rollback:** revert catalog; keep old `configEffect`.

---

## PR 3 — Introduce a real Creative OS receipt for setup execution

Currently `WubStateSetup` runs steps and reports failures, but does not produce a Creative OS setup receipt.

**Goal:** Create a minimal `creative_os_setup_receipt.v1.json` per run.

**Files touched:**

- `tools/automation/swift-cli/Sources/StudioCore/WubCli.swift` (executeStep + state-setup)
- New: `tools/automation/swift-cli/Sources/StudioCore/CreativeOSReceiptModels.swift`
- `tools/automation/swift-cli/Sources/StudioCore/RunContext.swift` (if needed)

**Key changes:**

- In `state-setup`, create a run directory under `runs/` (like `ApplyService` does).
- Emit:
  - `runs/<run_id>/creative_os_setup_receipt.v1.json`
  - includes:
    - plan snapshot hash (or embedded plan steps ids)
    - executed steps list
    - exit codes / errors
    - timestamps
    - environment (repo version if available)

**Acceptance criteria:**

- Running `wub state-setup` always writes a receipt (even if no steps executed).
- Drift/index can later consume those receipts.

**Rollback:** remove receipt writing; keep behavior.

---

## PR 4 — Split WubAgents.swift into per-domain agent files (move-only PR)

**Goal:** Make refactors surgical by isolating domains, without changing behavior.

**Files touched (move-only):**

- `tools/automation/swift-cli/Sources/StudioCore/WubAgents.swift` (shrinks to glue or deleted)
- New folder: `tools/automation/swift-cli/Sources/StudioCore/Agents/`
  - `ProfileAgent.swift`
  - `PackAgent.swift`
  - `MappingAgent.swift`
  - `SweeperAgent.swift`
  - `DriftAgent.swift`
  - `ReadyAgent.swift`
  - `StationAgent.swift`
  - `AssetsAgent.swift`
  - `VoiceRackSessionAgent.swift`
  - `IndexAgent.swift`
  - `ReleaseAgent.swift`
  - `ReportAgent.swift`
  - `RepairAgent.swift`
- `tools/automation/swift-cli/Sources/StudioCore/WubRuntime.swift` (imports updated)

**Key changes:**

- Pure file moves + imports.
- Keep the config structs where they are for now (or move to `Agents/Config/*` but still move-only).

**Acceptance criteria:**

- No behavior change; tests should prove same plan steps as before (snapshot test recommended).

**Rollback:** revert file moves.

---

## PR 5 — Migrate agent configs into service configs (reduce duplicate config types)

Right now `SweeperConfig`, `DriftConfig`, etc. are agent-local types, and then re-mapped in `ServiceExecutor` anyway.

**Goal:** Use `*Service.Config` as the canonical config type everywhere.

**Files touched:**

- `tools/automation/swift-cli/Sources/StudioCore/WubRuntime.swift`
- `tools/automation/swift-cli/Sources/StudioCore/WubCli.swift`
- `tools/automation/swift-cli/Sources/StudioCore/Agents/*Agent.swift`
- `tools/automation/swift-cli/Sources/StudioCore/*Service.swift` (only if config types need small changes)

**Key changes:**

- Replace:
  - `SweeperConfig` → `SweeperService.Config`
  - `DriftConfig` → `DriftService.Config` (or a smaller `DriftService.CheckConfig` if needed)
  - etc.
- `WubContext` holds service configs directly.
- Agents accept service configs directly.
- Action catalog uses those configs to generate effect payloads.

**Acceptance criteria:**

- Reduction in duplicated config structs.
- All CLI flags still work and route into service configs.

**Rollback:** revert to agent config structs.

---

## PR 6 — Station gating consolidation (single choke point)

Currently, station gating exists in:

- `ApplyService.run` (calls `StationGate.enforceOrThrow`)
- potentially elsewhere ad hoc

**Goal:** Make station gating a shared preflight for any mutating, automated Creative OS step.

**Files touched:**

- `tools/automation/swift-cli/Sources/StudioCore/WubCli.swift` (executeStep)
- `tools/automation/swift-cli/Sources/StudioCore/ServiceExecutor.swift`
- `tools/automation/swift-cli/Sources/StudioCore/StationGate.swift`
- `tools/automation/swift-cli/Sources/StudioCore/Agents/StationAgent.swift`

**Key changes:**

- Add a “mutating action allowlist” or action metadata in `CreativeOSActionCatalog`:
  - kind: `.setup` / `.repair` / `.release` etc.
  - `requiresStationGate: Bool`
- In `executeStep`:
  - if action requires gate, call `StationGate.enforceOrThrow(...)` before executing.
- Keep `ApplyService`’s gating for legacy PlanV1 apply (do not remove yet).

**Acceptance criteria:**

- Any automated step that can change state is gated.
- Safe read-only steps (e.g. `drift.check`, `station.status`) can be exempted.

**Rollback:** revert gating integration.

---

## PR 7 — Convert “manual-required because state mismatch” into typed checks + repair plans

`CreativeOSRuntime.diff()` emits generic manual steps when observed ≠ desired. That’s too vague for a Creative OS.

**Goal:** Replace generic `state_mismatch` with agent-specific checks and recommended fix steps.

**Files touched:**

- `tools/automation/swift-cli/Sources/StudioCore/CreativeOSRuntime.swift`
- `tools/automation/swift-cli/Sources/StudioCore/Agents/*Agent.swift`
- `tools/automation/swift-cli/Sources/StudioCore/CreativeOSModels.swift`

**Key changes:**

- Treat `diff()` as a last resort (missing agent state).
- Push “mismatch logic” into each agent:
  - agent registers a `CheckResult` with observed/expected + suggested actionRefs.
  - agent registers corresponding plan steps.
- Keep the current `diff()` but reduce its role.

**Acceptance criteria:**

- `state-plan` becomes meaningful: fewer generic `state_diff` steps, more typed steps.
- Checks are stable and deterministic.

**Rollback:** revert to generic diff behavior.

---

## PR 8 — Make ServiceExecutor pluggable (agent boundary hardening)

As the OS grows, a large switch statement becomes a merge-conflict magnet.

**Goal:** Turn `ServiceExecutor` into a registry: action ID → handler.

**Files touched:**

- `tools/automation/swift-cli/Sources/StudioCore/ServiceExecutor.swift`
- New: `tools/automation/swift-cli/Sources/StudioCore/Execution/ActionHandler.swift`
- `tools/automation/swift-cli/Sources/StudioCore/CreativeOSActionCatalog.swift`

**Key changes:**

- Each domain registers its handlers:
  - `StationActionHandlers.register(into:)`
  - `SweeperActionHandlers.register(into:)`
  - etc.
- `ServiceExecutor.execute(step:)` becomes:
  - look up handler
  - validate config
  - run
- This aligns perfectly with agent modularization.

**Acceptance criteria:**

- No behavior change.
- Adding new actions no longer touches a central switch.

**Rollback:** revert to switch.

---

## PR 9 — Introduce schema validation + checksum verification in CI (OS governance)

You already have checksum scripts and schemas. CI doesn’t enforce them.

**Goal:** “Governance as code.”

**Files touched:**

- `.github/workflows/swift-tests.yml`
- `tools/checksum_verify.sh`
- `specs/automation/schemas/*` (if missing schema for Creative OS receipt)

**Key changes:**

- Add CI steps:
  - `tools/checksum_verify.sh`
  - validate JSON files against schemas (even a small Swift-based validator is fine, or a lightweight node/python script)
  - ensure any generated indices are either:
    - checked in, or
    - generated and compared in CI.

**Acceptance criteria:**

- CI fails on checksum drift.
- CI fails on invalid schema.

**Rollback:** revert CI steps.

---

## PR 10 — Actuation subsystem boundary prep (optional, later)

This repo contains a serious UI automation runtime (ApplyRunner, actuators, OCR, evidence). Don’t refactor it until Creative OS kernel is stable.

**Goal:** Put Actuation into a clean module boundary without changing behavior.

**Files touched:**

- `tools/automation/swift-cli/Sources/StudioCore/ApplyRunner.swift` (+ related files)
- `tools/automation/swift-cli/Sources/StudioCore/Actuator.swift`, `ReliableTeensyActuator.swift`, `CGEventActuator.swift`
- OCR/capture files: `FrameCapture.swift`, `VisionOCR.swift`, `OCRMatcher.swift`, etc.
- Trace/receipt files: `TraceWriter.swift`, `ReceiptWriter.swift`, `TraceModels.swift`, `ReceiptModels.swift`

**Key changes:**

- Create folder: `Sources/StudioCore/Actuation/*` and move-only.

**Acceptance criteria:**

- `wub apply` behaves unchanged.

**Rollback:** revert move-only PR.

---

## Definition of done

You can declare the Creative OS target “real” when:

1. `wub state-plan` emits a plan where most steps are executable (`actionRef`) and not shell strings.
2. `wub state-setup`:
   - gates mutating actions via `StationGate`
   - writes a deterministic Creative OS setup receipt
3. Agents:
   - own their checks
   - own their repair/setup plans
   - are packaged per domain in `Sources/StudioCore/Agents/`
4. `ServiceExecutor` is registry-based and domain-owned.
5. CI enforces:
   - Swift tests
   - checksum verification
   - schema validation

---

## Immediate next move (recommended start)

If you want the safest high-leverage start, do these first:

1. PR 0 (tests)
2. PR 1 (permissioned execution model)
3. PR 2 (config catalog)

That trio will immediately make Creative OS “setup” real, without forcing a big reorg.
