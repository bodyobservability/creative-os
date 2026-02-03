# APC40 Layout

Version: current

Purpose: make bass sound design and capture **performable**. APC40 is the "energy and commitment" surface.

This layout is written so it can be implemented on APC40 mk1 or mk2. If a control differs between models, document the deviation in a v1.0-MK2 note and do not change semantics.

## Assumptions (Ableton set)
- Track order includes at minimum:
  1) BASS_MAIN (instrument)
  2) BASS_RESAMPLE (audio)
  3) VOCAL_REFERENCE (optional)
  4) DRUMS/KEY (optional)
- BASS_MAIN exposes 8 macros (Macro 1..8) per `macro_taxonomy.md`.
- BASS_RESAMPLE is armed and ready for capture when in bass mode.

## High-level mapping strategy
- Bank A = Macros 1-8 (primary performance bank)
- Bank B = "extremes and utilities" (rare, deliberate)
- Clip grid = capture and variation management
- Transport = record/undo/loop discipline

## Track Control Section
### Track select buttons
- Track Select 1 -> focus BASS_MAIN
- Track Select 2 -> focus BASS_RESAMPLE
- Track Select 3 -> focus VOCAL_REFERENCE (if present)
- Track Select 4 -> focus DRUMS/KEY (if present)

### Faders (top to bottom)
- Fader 1 (Track 1) -> BASS_MAIN level (post-rack, pre-master)
- Fader 2 (Track 2) -> BASS_RESAMPLE playback level
- Fader 3 (Track 3) -> VOCAL_REFERENCE level (if present)
- Fader 4 (Track 4) -> DRUMS/KEY level (if present)
- Master fader -> Master level (normally fixed; treat as safety)

### Track activator (mute) buttons
- Track 1 Activator -> Mute/unmute BASS_MAIN (performance kill switch)
- Track 2 Activator -> Mute/unmute BASS_RESAMPLE playback
- Track 3 Activator -> Mute/unmute VOCAL_REFERENCE

### Solo buttons
Avoid solo in normal use (too easy to break monitoring context). If needed:
- Solo Track 1 -> audition bass only

## Device Control Knobs
The APC40 Device Control section provides 8 knobs. These map directly to macros on BASS_MAIN.

### Bank A (default): Macro performance
Knob 1 -> Macro 1 (CUT)
Knob 2 -> Macro 2 (SUB)
Knob 3 -> Macro 3 (DRIVE)
Knob 4 -> Macro 4 (MOV)
Knob 5 -> Macro 5 (WID)
Knob 6 -> Macro 6 (AIR)
Knob 7 -> Macro 7 (PUNCH)
Knob 8 -> Macro 8 (GRIT)

### Bank B (rare): extremes + utilities
Bank B should only be used if it does NOT compromise Bank A muscle memory.
Suggested mapping (implement as Rack macros 9-16 internally, or map Bank B to secondary Rack):
- Knob 1 -> CUT_EXT (opens higher / lower extremes)
- Knob 2 -> SUB_EXT (sub boost beyond safe zone; includes limiter compensation)
- Knob 3 -> DRIVE_EXT (hard clip / fold; compensation required)
- Knob 4 -> MOV_RATE (LFO rate range)
- Knob 5 -> WID_EXT (super-wide / chorus depth; high band only)
- Knob 6 -> AIR_EXT (fizz zone; ensure de-esser / EQ guard)
- Knob 7 -> PUNCH_EXT (click/attack zone)
- Knob 8 -> GRIT_EXT (bitcrush / downsample extremes)

If Bank B is not implemented, leave it unused rather than inventing ad-hoc mappings.

## Clip Matrix (8x5)
The grid is for capture, not composition.

### Rows (vertical) = capture lanes / variations
Row 1: "SAFE" bass captures (default macro ranges)
Row 2: "AGGRO" captures (drive/grit emphasis)
Row 3: "WIDE/MOV" captures (width + motion emphasis)
Row 4: "ALT" captures (family-specific experiments)
Row 5: reserved (do not use unless documented)

### Columns (horizontal) = takes over time
Column 1-8 represent sequential takes.

### Action
- Press empty slot on BASS_RESAMPLE track to begin recording a new clip (session record behavior).
- When clip ends, immediately name it (see naming rules below).

### Naming rules
Format: `BASS_<FAMILY>_<MOOD>_<BPM>_<TAKE#>`
Example: `BASS_WARM_BUILD_128_T03`

## Transport / global
- Play: start
- Stop: stop (do not spam; keep context stable)
- Rec: session record (capture automation + clip recording)
- Undo: critical; keep it accessible and use it instead of "tweak back"
- Metronome: on only if it helps; default off for feel-driven takes

## Acceptance checklist
- With one held note, all 8 knobs produce predictable changes.
- Record a 30s performance: automation is captured and the resample clip matches what was heard.
- You can create 3 distinct bass takes in under 5 minutes without touching the mouse.
