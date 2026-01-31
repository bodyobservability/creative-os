# v9.2 Mapping Worksheet (Phrase → MIDI)

Fill this in while configuring Voice Control + KM.

| Trigger ID | Phrase | MIDI type | CC/Note | Value/Vel | Channel | Bus |
|---|---|---:|---:|---:|---:|---|
| wub_up | wub up | CC | 14 | 96 | 1 | HVLIEN_VOICE |
| wub_down | wub down | CC | 14 | 32 | 1 | HVLIEN_VOICE |
| open_filter | open filter | CC | 21 | 110 | 1 | HVLIEN_VOICE |
| close_filter | close filter | CC | 21 | 40 | 1 | HVLIEN_VOICE |
| sidechain_on | sidechain on | Note | 60 | 127 | 1 | HVLIEN_VOICE |
| sidechain_off | sidechain off | Note | 61 | 127 | 1 | HVLIEN_VOICE |
| drop_riser | drop riser | Note | 48 | 127 | 1 | HVLIEN_VOICE |
| next_scene | next scene | Note | 50 | 127 | 1 | HVLIEN_VOICE |
| arm_bass | arm bass | Note | 40 | 127 | 1 | HVLIEN_VOICE |
| arm_vox | arm vox | Note | 41 | 127 | 1 | HVLIEN_VOICE |
| record_take | record take | Note | 36 | 127 | 1 | HVLIEN_VOICE |

Notes:
- Prefer explicit ON/OFF notes instead of toggles.
- Keep phrases short and distinct; add “hv” prefix if needed.

