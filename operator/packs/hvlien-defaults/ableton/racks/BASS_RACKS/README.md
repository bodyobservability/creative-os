# BASS_RACKS

This folder stores exported Ableton racks (`.adg`) that implement the HVLIEN profile bass instrument.

Racks are first-class artifacts because they encode:
- macro semantics (the playable surface)
- safe-zone clamping
- compensation (gain trim, mono safety for sub, etc.)

## Naming
`HVLIEN_BASS_<FAMILY>_v1.0.adg`
Examples:
- `HVLIEN_BASS_WARM_v1.0.adg`
- `HVLIEN_BASS_AGGRO_v1.0.adg`
- `HVLIEN_BASS_HOLLOW_v1.0.adg`

## Required macros (contract)
Every rack MUST expose **8 macros** following:
- `controllers/macro_taxonomy.md`

Macro order must remain 1..8. Do not shuffle.

## Recommended rack structure
- Instrument chain:
  - Serum (preferred) OR Ableton Instrument (Wavetable/Operator)
- Tone chain:
  - Auto Filter (optional)
  - Saturator / Drive stage (with output trim)
- Dynamics:
  - Glue/Compressor (optional)
  - Limiter as safety (light)
- Imaging:
  - Utility for mono sub (low band)
  - Width on high band only

If you need multiband behavior, document it and keep it simple.

## Safe-zone philosophy
- 0-70%: playable and generally "safe"
- 70-100%: expressive / aggressive

If a macro is dangerous (silence, runaway volume, harsh clipping), clamp range and expose extremes via:
- secondary bank (APC40 Bank B), or
- a documented "EXT" rack version

## Acceptance tests (per rack)
1) Hold a note. Sweep each macro 0->100->0.
2) Confirm no dead zones.
3) Confirm SUB stays mono and does not overload.
4) Record 30s macro performance; confirm automation is smooth and resample matches monitoring.

## TODO to make this repo truly complete
- Export at least 3 racks as `.adg` and place them here.
- Add a short demo clip per rack under `library/demos/`.
