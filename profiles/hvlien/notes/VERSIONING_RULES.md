# VERSIONING RULES

## Allowed changes (value-level tuning)
- EQ cutoff (within 25–40 Hz)
- Glue threshold (maintain 1–2 dB GR max)
- Saturator drive (small offsets)
- Utility width (within defined bay ranges)
- Limiter input (headroom adjustments)

## Forbidden changes (structural)
- Track additions/removals
- Routing changes
- Device insertion/removal
- Per-track edits (warping, fades, clip gain, automation)

## Version bump policy
- Any structural change requires a new minor version:
  - `HVLIEN_FINISHING_BAY_v1.1.als`
- Specs must be updated in `specs/` accordingly.
