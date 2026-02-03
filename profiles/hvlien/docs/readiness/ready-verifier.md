# Ready verifier

## Version
Version: v1.8.4

## History
- (none)


Command:
```bash
wub ready --anchors-pack-hint specs/automation/anchors/<pack_id>
```

Checks:
- artifact index exists + pending artifacts count
- anchors pack path exists (warn if missing)
- latest drift status (best-effort)

Outputs:
- stdout summary
- `runs/<run_id>/ready_report.v1.json` (by default)

Wiring:
- add `Ready.self` to CLI entrypoint
