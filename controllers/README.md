# Controllers

This folder defines the **stable controller layer** for the HVLIEN profile bass instrument.

These docs are not optional: the goal is to make bass production repeatable at high speed across sessions, without re-inventing mappings.

## What lives here
- Macro taxonomy (the conceptual contract)
- Hardware layout docs for APC40 and MPK Mini
- Change log for mapping semantics

## Files
- `macro_taxonomy.md` - the 8-macro contract (must not drift)
- `apc40_layout.md` - energy and capture surface
- `mpk_mini_layout.md` - pitch and intent surface

## Implementation notes
These docs must be implemented in Ableton as:
- an Ableton Template Set (or a dedicated Bass Performance Set)
- racks that expose 8 macros on `BASS_MAIN`
- stable controller mappings

If you export Ableton racks (`.adg`) or templates (`.als`), store them under:
- `packs/hvlien-defaults/ableton/racks/...
- `packs/hvlien-defaults/ableton/performance-sets/...

Do not store hardware driver installers or vendor editors in this repo.

## Change control
- Any change to controller semantics requires:
  1) bumping doc versions (e.g., v1.0 -> v1.1)
  2) writing a change log entry below
  3) regenerating checksums

## Change log
- v1.0 (initial)
  - Established 8-macro taxonomy and APC40/MPK baseline mapping.
