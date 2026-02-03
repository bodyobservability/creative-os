# Drift Detection UX

Version: current


Adds:
- `wub drift check`
- `wub drift explain <artifact>`

## Design goals
- Helpful, not naggy
- Pull-based (you run it)
- Severity tiers (info/warn/fail)
- One-line fix command suggestions

## Usage
1) Build indexes:
```bash
wub index build
```

2) Check drift:
```bash
wub drift check --anchors-pack-hint specs/automation/anchors/<pack_id>
```

3) Explain a finding:
```bash
wub drift explain packs/hvlien-defaults/ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als
```

## Notes
- v1.8.1 uses artifact `status.state` from artifact_index.v1.json (missing/placeholder/unknown).
- Stale detection becomes meaningful in v1.8.2 once we add per-rack expansion and receipt recency comparisons.
