# MPK Mini Layout

Version: current

Purpose: MPK Mini is the "pitch and intent" surface.

It should feel like a small instrument that can be picked up and immediately used to write basslines, even if APC40 is unavailable.

## Assumptions
- MPK Mini is configured as a standard MIDI input in Ableton.
- Use a fixed MIDI channel (default is fine) and do not rely on per-project device scripts.

## Keys
- Keys play the currently selected instrument (normally BASS_MAIN).
- Octave +/- changes register during exploration.
- Keybed is used for:
  - root note anchoring
  - interval exploration (thirds, fifths, sevenths)
  - rhythmic bass patterns

### Recommended playing conventions (to keep bass consistent)
- Treat C1..C3 as the primary bass performance zone.
- When going higher for harmonics, do it deliberately (octave button, not random).

## Pads (8)
Pads should prioritize *workflow actions* over drums unless a track explicitly needs drums.

Suggested default pad map (Ableton MIDI mapping):
1) Pad 1 -> Arm BASS_RESAMPLE (toggle)
2) Pad 2 -> Session Record (toggle)
3) Pad 3 -> Clip Stop (BASS_RESAMPLE)
4) Pad 4 -> New Clip (BASS_RESAMPLE, next slot)
5) Pad 5 -> Mute BASS_MAIN (momentary or toggle)
6) Pad 6 -> Undo
7) Pad 7 -> Next Scene
8) Pad 8 -> Previous Scene

If the project requires drum reference, use a documented alternate mode:
- Pads become drum hits for SIDECHAIN_KEY or a minimal kick/snare grid.
- Alternate mode must be named and versioned.

## Knobs (8)
Knobs provide macro access when APC40 is not present, and "secondary access" when APC40 is present.

### Mode A (no APC40 present): full macro mirror
Knob 1 -> CUT
Knob 2 -> SUB
Knob 3 -> DRIVE
Knob 4 -> MOV
Knob 5 -> WID
Knob 6 -> AIR
Knob 7 -> PUNCH
Knob 8 -> GRIT

### Mode B (APC40 present): offsets / fine trim
If APC40 is present and Bank A is in use, MPK knobs may be used as *offsets* or *fine trims*:
- Knob 1 -> CUT_FINE (small range)
- Knob 2 -> SUB_FINE
- Knob 3 -> DRIVE_FINE
- Knob 4 -> MOV_FINE
- Knob 5 -> WID_FINE
- Knob 6 -> AIR_FINE
- Knob 7 -> PUNCH_FINE
- Knob 8 -> GRIT_FINE

If offsets are used, implement them as Rack macros that add/subtract within a clamp, not as competing mappings to the same parameter.

## Velocity and feel
- Set pad velocity curve so 20-80% is most common.
- For keys, choose a curve that favors consistent bass dynamics (avoid extreme sensitivity).

## Acceptance checklist
- With only MPK Mini connected, you can:
  - play bass notes
  - shape sound via 8 macros
  - start/stop capture into BASS_RESAMPLE with minimal mouse use
