# Capabilities

Groupings are by intent, not subcommand names. Each entry shows when to run, prerequisites, outputs, and recovery.

## Perception and Safety

### Sweep (modal guard)

When to run:

- Before automation if the UI may have blocking modals.

Prereqs:

- Anchors pack configured.

Outputs:

- Sweep report under `runs/<id>/...`.

Recovery:

- Close modals or permissions, then re-run sweep.

## Provisioning

### Assets export-* (including export-all)

When to run:

- When artifact index shows missing or placeholder entries.

Prereqs:

- Anchors pack configured.
- Sweep passes.

Outputs:

- Export receipts under `runs/<id>/...`.
- Updated artifacts in repo.

Recovery:

- Re-run export-all for missing categories.

## Bookkeeping

### Index build/status

When to run:

- After any asset export.

Prereqs:

- Artifacts present on disk.

Outputs:

- `checksums/index/artifact_index.v1.json`.

Recovery:

- Re-run index build if status fails or is missing.

## Divergence

### Drift check/plan/fix

When to run:

- Before certification or release.

Prereqs:

- Index exists.

Outputs:

- Drift report under `runs/<id>/...`.

Recovery:

- Run drift plan, then drift fix if required.

## Readiness

### Ready verify/certify

When to run:

- Before operating in automation.

Prereqs:

- Anchors, sweep, index, artifacts complete.

Outputs:

- Ready report under `runs/<id>/...`.

Recovery:

- Run repair if ready verify fails.

## Voice Runtime

### VRL validate/run

When to run:

- After updating mappings or voice runtime configs.

Prereqs:

- VRL mapping file present.

Outputs:

- Validation output or runtime logs.

Recovery:

- Fix mapping errors and re-run validation.
