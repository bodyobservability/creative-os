# Drift UX Polish + Fix Planning

## Version
Version: current

## History
- history/drift-legacy.md


Adds UX improvements on top of v1.8.1/1.8.2:

- `wub drift check --format human|json`
- `wub drift check --group-by-fix`
- `wub drift plan` (commands-only remediation plan)

## Helpful-not-naggy behavior
- Default output groups by the single command that fixes the most.
- `--only-fail` keeps output calm during active sessions.
- Fix suggestions are explicit; nothing auto-runs.

## Examples
```bash
wub index build
wub drift check --anchors-pack-hint specs/automation/anchors/<pack_id>
wub drift plan  --anchors-pack-hint specs/automation/anchors/<pack_id>
wub drift explain packs/hvlien-defaults/ableton/racks/BASS_RACKS_v1.0/SomeRack.adg
```
