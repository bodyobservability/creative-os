# v1.7.16 — Station Status

Command:
```bash
hvlien station status --format human
hvlien station status --format json --no-write-report
```

Writes:
- `runs/<run_id>/station_state_report.v1.json` (unless `--no-write-report`)

Signals (v1):
- OS frontmost application
- optional mode latch in `notes/LOCAL_CONFIG.json` (mode=performance)

Planned (v1.7.17):
- integrate modal/save-sheet detection
- conservative gating for mutating commands
