# Index Precision + Stale Detection

## Version
Version: v1.8.2

## History
- history/index-legacy.md


Adds two major improvements over v1.8.0:

1) **Rack expected-artifact expansion**
- `racks_export.v1.yaml` is now expanded into a concrete list of expected `.adg` files using:
  - `profiles/hvlien/specs/library/racks/rack_pack_manifest.v1.json` display names
  - output directory from `profiles/hvlien/specs/assets/export/racks_export.v1.yaml`
  - filename sanitization consistent with export pipeline

2) **Stale detection**
- An artifact can be marked `stale` if its file mtime is older than the most recent receipt timestamp for the same export job.
- Includes budgets:
  - warn after 24h
  - fail after 7d

This unlocks drift UX that is informative without being naggy (budgets prevent constant warnings during active work).
