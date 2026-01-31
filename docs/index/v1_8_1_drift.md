# v1.8.1 — Drift Detection UX

Adds:
- `hvlien drift check`
- `hvlien drift explain <artifact>`

## Design goals
- Helpful, not naggy
- Pull-based (you run it)
- Severity tiers (info/warn/fail)
- One-line fix command suggestions

## Usage
1) Build indexes:
```bash
hvlien index build
```

2) Check drift:
```bash
hvlien drift check --anchors-pack-hint specs/automation/anchors/<pack_id>
```

3) Explain a finding:
```bash
hvlien drift explain ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als
```

## Notes
- v1.8.1 uses artifact `status.state` from artifact_index.v1.json (missing/placeholder/unknown).
- Stale detection becomes meaningful in v1.8.2 once we add per-rack expansion and receipt recency comparisons.
