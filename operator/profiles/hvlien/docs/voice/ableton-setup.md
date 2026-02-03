# Ableton Runtime Setup (Voice → MIDI)

## Version
Version: current

## History
- (none)


This document explains how to map v9 Voice Runtime MIDI events to Ableton Live actions using MIDI Map Mode.

## Core Rules
- MIDI input source must be **WUB_VOICE**
- One phrase = one MIDI event = one Ableton action
- Macro jumps must be bounded

## Macro Mapping
- Motion (Macro 2): CC14
  - wub down → 0.25
  - wub up → 0.75

- Tone (Macro 3): CC21
  - close filter → 0.30
  - open filter → 0.80

## Sidechain Toggle
- Note 60 → Device ON
- Note 61 → Device OFF

## Arrangement
- Note 48 → Launch RISER clip
- Note 50 → Next Scene

## Tracking
- Note 40 → Arm BASS track
- Note 41 → Arm VOX track

## Transport
- Note 36 → Session Record

All mappings must be verified in MIDI Map Mode.
