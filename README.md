# Creative OS

Creative OS is a safety-first execution kernel for studio stations: allowlisted actions, gated execution, deterministic receipts, and governance.
Studio Operator is the operator persona and shell (TUI/voice/workflows) that drives Creative OS via `wub`.

## First Run

```bash
make onboard
```

See `docs/studio-operator/first_run.md`.

## Studio Operator Shell

```bash
make studio
```

See `operator/profiles/hvlien/docs/voice/operator-shell.md`.

## Capabilities

See `docs/studio-operator/capabilities.md`.

## Modes

See `docs/studio-operator/modes.md`.

## Quickstart (manual)

Build the CLI:
```bash
cd kernel/cli
swift build -c release
```

Run the core commands:
```bash
kernel/cli/.build/release/wub sweep
kernel/cli/.build/release/wub plan --json
kernel/cli/.build/release/wub setup --show-manual
```

Select a profile:
```bash
kernel/cli/.build/release/wub profile use hvlien
```

Check station state:
```bash
kernel/cli/.build/release/wub station status --format json --no-write-report
```

## Creative OS safety model (read before `setup`)

- `wub setup` and `wub state-setup` default to dry-run and only execute allowlisted actions.
- Mutating actions are gated by `StationGate` and emit receipts under `runs/<run_id>/`.
- If an action is not in the allowlist, it will be visible in plans but not executed.

## Studio Operator Shell

- Launch the Operator Shell (TUI): `wub ui`
- See `operator/profiles/hvlien/docs/voice/operator-shell.md`

## Profiles and packs (kernel + operator)

- Profiles live in `operator/profiles/` (for example `operator/profiles/hvlien.profile.yaml`).
- Packs live in `operator/packs/` and can be attached to a profile.
- Active selection is stored in `operator/notes/WUB_CONFIG.json`.
- Local-only overrides live in `operator/notes/LOCAL_CONFIG.json` (not committed).

## Repo layout (current)

- `kernel/cli/` — Creative OS kernel entrypoint (`wub`)
- `kernel/tools/` — kernel-owned tooling (validation, checksums, hooks)
- `operator/profiles/` — kernel-validated identity + policy
- `operator/packs/` — optional operator payloads
- `shared/specs/` — kernel contracts, schemas, and runbooks
- `shared/contracts/` — cross-domain contracts (materials, manufacturing, evidence)
- `docs/` — Creative OS + Studio Operator docs
- `operator/notes/` — operational notes and checklists

## Maintainer workflow

- CLI reference: `docs/creative-os/automation/cli_reference.md`
- First machine checklist: `docs/shared/release/fresh_machine_smoke_checklist.md`
- Versioning rules: `operator/profiles/hvlien/notes/versioning-rules.md`
- After changing shared/specs/docs, regenerate checksums:
  - `bash kernel/tools/checksum_generate.sh`
- Schema validation:
  - `kernel/tools/schema_validate.py`
- CI workflows:
  - `.github/workflows/governance.yml`
  - `.github/workflows/swift-tests.yml`

## Roadmap (Creative OS)

The canonical roadmap lives in `docs/creative-os/ROADMAP.md`.
