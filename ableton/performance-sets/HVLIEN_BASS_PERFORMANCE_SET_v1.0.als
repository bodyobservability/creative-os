PLACEHOLDER - CREATE THIS ABLETON LIVE SET MANUALLY

Set name: HVLIEN_BASS_PERFORMANCE_SET_v1.0

Why a placeholder:
- Ableton .als is a binary project file. This repo stores the spec and build steps so the set can be recreated deterministically and versioned.

## Purpose
A dedicated playground for bass writing and macro performance that:
- is controller-first (APC40 + MPK)
- records automation and audio quickly
- encourages early commitment via resampling

## Required tracks (in this exact order)
1) BASS_MAIN (MIDI/Instrument)
2) BASS_RESAMPLE (Audio)
3) BASS_PRINTS (Audio)
4) SIDECHAIN_KEY (MIDI or Audio, optional)
5) VOCAL_REFERENCE (Audio, optional)

## Devices and routing
### Track 1: BASS_MAIN
- Instrument: Serum (preferred) or Ableton Rack
- MUST be wrapped in an Instrument Rack exposing **8 Macros** following:
  controllers/MACRO_TAXONOMY_v1.0.md
- Optional: light safety limiting on the bass chain to prevent runaway loudness.

### Track 2: BASS_RESAMPLE
- Audio From: BASS_MAIN (Post-FX)
- Monitor: IN (during capture) or AUTO (if you prefer arming discipline)
- Arm for recording.

### Track 3: BASS_PRINTS
- Used for consolidated takes (selected clips from BASS_RESAMPLE)
- No monitoring required.

### Sidechain (optional)
- SIDECHAIN_KEY drives compressor on BASS_MAIN or bass bus.
- If used, keep it fixed and documented (do not re-tune sidechain every session).

## Controller expectations
### APC40
- Device Control Knobs 1-8 -> Macros 1-8 on BASS_MAIN (Bank A)
- Fader 1 -> BASS_MAIN level
- Fader 2 -> BASS_RESAMPLE playback level
- Clip grid -> record and manage takes on BASS_RESAMPLE
(See controllers/APC40_LAYOUT_v1.0.md)

### MPK Mini
- Keys -> play BASS_MAIN
- Knobs -> mirror macros (if APC40 absent) or fine trims (if APC40 present)
- Pads -> capture workflow actions (arm, record, new clip, undo)
(See controllers/MPK_MINI_LAYOUT_v1.0.md)

## Build steps (deterministic)
1) Create tracks in the exact order above.
2) Insert Serum on BASS_MAIN and wrap in Instrument Rack.
3) Map internal parameters to the 8 rack macros per taxonomy.
4) Configure BASS_RESAMPLE input from BASS_MAIN post-FX.
5) Configure APC40 as Control Surface (Ableton Preferences).
6) Map APC40 Device Control to rack macros (confirm knobs follow 1-8).
7) Map MPK pads (optional) to capture actions.
8) Save as "HVLIEN_BASS_PERFORMANCE_SET_v1.0.als".

## Acceptance tests
- Hold a note: sweep macros 1-8. All are musically usable.
- Record a 30s performance: automation + audio are captured.
- Create 3 distinct bass takes in under 5 minutes without mouse edits.
