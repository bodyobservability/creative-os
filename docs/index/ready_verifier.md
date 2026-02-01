# Ready verifier (v1.7.14)

Command:
```bash
hvlien ready --anchors-pack-hint specs/automation/anchors/<pack_id>
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
