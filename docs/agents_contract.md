# Agent Contract (Phase A)

This document defines the minimal agent/service contract used during migration.

## Agent interface
Agents expose:
- `observeState()` → `ObservedStateSlice` (what is true now)
- `desiredState()` → `DesiredStateSlice?` (optional target policy)
- `registerChecks()` → `CheckResult` entries (health/status)
- `registerPlans()` → `PlanStep` entries (actions)

## Service result shape (recommended)
Services should return a structured bundle so agents and CLI can share logic:
- `observed` (optional) — `ObservedStateSlice`
- `desired` (optional) — `DesiredStateSlice`
- `checks` — `[CheckResult]`
- `steps` — `[PlanStep]`

This enables:
- CLI commands to call services directly.
- Agents to adapt service output into the Creative OS runtime without duplicating logic.

## Domain mapping guidance
- **State slices**: durable facts (inventory, active profile, packs, station state)
- **Checks**: evaluation results (pass/warn/fail) with evidence
- **Plans**: concrete actions; `manual_required` unless automation is safe

## Conventions
- Use `agent` id for all outputs (checks/steps).
- Sort outputs by `(agent, id)` for deterministic order.
- Prefer explicit inputs from profile policy; allow CLI flags to override.
