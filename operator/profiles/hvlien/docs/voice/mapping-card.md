# Voice Runtime Mapping Card (ABI-Compliant)

## Version
Version: current

## History
- history/mapping-card-legacy.md

MIDI BUS: WUB_VOICE | Channel: 1

MACRO JUMPS
-----------
"wub up"       → CC14=96  → Motion (M2) → high motion
"wub down"     → CC14=32  → Motion (M2) → low motion

"open filter"  → CC21=110 → Tone (M3)   → bright
"close filter" → CC21=40  → Tone (M3)   → dark

TOGGLES
-------
"sidechain on"  → Note 60 → Sidechain ON
"sidechain off" → Note 61 → Sidechain OFF

ARRANGEMENT
-----------
"drop riser" → Note 48 → Launch RISER
"next scene" → Note 50 → Next Scene

TRACKING
--------
"arm bass" → Note 40 → Arm BASS
"arm vox"  → Note 41 → Arm VOX

TRANSPORT
---------
"record take" → Note 36 → Session Record
