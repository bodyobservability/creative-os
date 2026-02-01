HVLIEN v9 — Voice Runtime Mapping Card
====================================

VOICE PHRASE     →  MIDI         →  TARGET
------------------------------------------------
"wub up"         →  CC14 = 96    →  WUB_RATE ↑
"wub down"       →  CC14 = 32    →  WUB_RATE ↓
"open filter"    →  CC21 = 110   →  FILTER ↑
"close filter"   →  CC21 = 40    →  FILTER ↓

"sidechain on"   →  Note 60      →  Sidechain ON
"sidechain off"  →  Note 61      →  Sidechain OFF

"drop riser"     →  Note 48      →  Riser clip
"next scene"     →  Note 50      →  Scene advance

"arm bass"       →  Note 40      →  Arm Bass track
"arm vox"        →  Note 41      →  Arm Vox track

"record take"    →  Note 36      →  Record clip
------------------------------------------------

MIDI BUS: WUB_VOICE
RULE: One phrase = one musical action
