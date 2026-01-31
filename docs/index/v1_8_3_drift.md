# v1.8.3 — Drift UX Polish + Fix Planning

Adds UX improvements on top of v1.8.1/1.8.2:

- `hvlien drift check --format human|json`
- `hvlien drift check --group-by-fix`
- `hvlien drift plan` (commands-only remediation plan)

## Helpful-not-naggy behavior
- Default output groups by the single command that fixes the most.
- `--only-fail` keeps output calm during active sessions.
- Fix suggestions are explicit; nothing auto-runs.

## Examples
```bash
hvlien index build
hvlien drift check --anchors-pack-hint specs/automation/anchors/<pack_id>
hvlien drift plan  --anchors-pack-hint specs/automation/anchors/<pack_id>
hvlien drift explain ableton/racks/BASS_RACKS_v1.0/SomeRack.adg
```
