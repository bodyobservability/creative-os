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

Launch the Operator Shell (TUI):
```bash
make studio
# or
tools/automation/swift-cli/.build/release/wub ui
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

## Roadmap (Studio Operator)

The canonical roadmap lives in `docs/ROADMAP.md` and includes the
Creative OS kernel plan plus the Studio Operator milestones.
