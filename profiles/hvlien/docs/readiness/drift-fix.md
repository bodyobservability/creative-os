# Drift Fix (Guarded)

## Version
Version: current

## History
- (none)


Adds `wub drift fix` to execute the remediation plan produced by drift check/plan.

## Principles
- Never auto-runs without explicit operator consent.
- Supports `--dry-run` to print commands only.
- Supports `--yes` to skip per-command prompts (still asks once unless you prefer yes + non-interactive shell usage).

## Usage
```bash
wub index build
wub drift check --anchors-pack-hint specs/automation/anchors/<pack_id>

# Preview commands only
wub drift fix --dry-run

# Execute with one confirmation
wub drift fix

# Execute without per-command prompts
wub drift fix --yes
```

Outputs a receipt:
- runs/<run_id>/drift_fix_receipt.v1.json
