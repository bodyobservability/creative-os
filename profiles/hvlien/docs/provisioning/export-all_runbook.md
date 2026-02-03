# Export All (Repo TODO Cleanup)

## Version
Version: current

## History
- (none)


This is the one-command pipeline to produce the repo-required artifacts:

- Export racks → packs/hvlien-defaults/ableton/racks/BASS_RACKS/
- Export performance set → packs/hvlien-defaults/ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als
- Export finishing bays → packs/hvlien-defaults/ableton/finishing-bays/*.als
- Export Serum base patch → library/serum/HVLIEN_SERUM_BASE_v1.0.fxp
- Export extras → returns + master safety racks

Command:
```bash
wub assets export-all   --anchors-pack specs/automation/anchors/<pack_id>   --overwrite
```

Notes:
- This command intentionally does NOT attempt to open/switch Ableton sets for bays.
  The finishing bays exporter will prompt you per bay unless you disable prompting.
- For Tahoe voice ergonomics: bind “export everything” to this command via KM/Shortcuts.
