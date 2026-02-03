# Creative OS

Creative OS is a safety-first execution kernel for studio stations: allowlisted actions, gated execution, deterministic receipts, and governance.
Studio Operator is the operator persona and shell (TUI/voice/workflows) that drives Creative OS via `wub`.

## First Run

```bash
make onboard
```

See `docs/first_run.md`.

## Studio Operator Shell

```bash
make studio
```

See `profiles/hvlien/docs/voice/operator-shell.md`.

## Capabilities

See `docs/capabilities.md`.

## Modes

See `docs/modes.md`.

## Quickstart (manual)

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

Select a profile:
```bash
tools/automation/swift-cli/.build/release/wub profile use hvlien
```

Check station state:
```bash
tools/automation/swift-cli/.build/release/wub station status --format json --no-write-report
```

## Creative OS safety model (read before `setup`)

- `wub setup` and `wub state-setup` default to dry-run and only execute allowlisted actions.
- Mutating actions are gated by `StationGate` and emit receipts under `runs/<run_id>/`.
- If an action is not in the allowlist, it will be visible in plans but not executed.

## Studio Operator Shell

- Launch the Operator Shell (TUI): `wub ui`
- See `profiles/hvlien/docs/voice/operator-shell.md`

## Profiles and packs (kernel + operator)

- Profiles live in `profiles/` (for example `profiles/hvlien.profile.yaml`).
- Packs live in `packs/` and can be attached to a profile.
- Active selection is stored in `notes/WUB_CONFIG.json`.
- Local-only overrides live in `notes/LOCAL_CONFIG.json` (not committed).

## Repo layout (current)

- `tools/automation/` — Creative OS kernel entrypoint (`wub`) and automation tooling
- `profiles/` — kernel-validated identity + policy
- `packs/` — optional operator payloads
- `specs/` — kernel contracts, schemas, and runbooks
- `docs/` — Creative OS + Studio Operator docs
- `notes/` — operational notes and checklists

## Maintainer workflow

- CLI reference: `docs/automation/cli_reference.md`
- First machine checklist: `docs/release/fresh_machine_smoke_checklist.md`
- Versioning rules: `profiles/hvlien/notes/VERSIONING_RULES.md`
- After changing specs/docs, regenerate checksums:
  - `bash tools/checksum_generate.sh`
- Schema validation:
  - `tools/schema_validate.py`
- CI workflows:
  - `.github/workflows/governance.yml`
  - `.github/workflows/swift-tests.yml`

## Roadmap (Creative OS)

The canonical roadmap lives in `docs/ROADMAP.md`.
