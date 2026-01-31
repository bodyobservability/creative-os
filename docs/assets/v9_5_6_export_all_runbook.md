# v9.5.6 — Export All (Repo TODO Cleanup)

This is the one-command pipeline to produce the repo-required artifacts:

- Export racks → ableton/racks/BASS_RACKS_v1.0/
- Export performance set → ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als
- Export finishing bays → ableton/finishing-bays/*.als
- Export Serum base patch → library/serum/HVLIEN_SERUM_BASE_v1.0.fxp
- Export extras → returns + master safety racks

Command:
```bash
hvlien assets export-all   --anchors-pack specs/automation/anchors/<pack_id>   --overwrite
```

Notes:
- This command intentionally does NOT attempt to open/switch Ableton sets for bays.
  The finishing bays exporter will prompt you per bay unless you disable prompting.
- For Tahoe voice ergonomics: bind “export everything” to this command via KM/Shortcuts.
