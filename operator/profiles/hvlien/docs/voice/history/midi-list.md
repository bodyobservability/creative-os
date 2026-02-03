# HVLIEN legacy — MIDI List Command

This bundle adds:
- `wub midi list`

Purpose:
- Show the exact CoreMIDI destination names as seen by the system.
- Use this to confirm the substring you should pass as `midi_dest` in apply plans (e.g. WUB_VOICE).

## Usage
```bash
wub midi list
```

## Wiring
Add `MidiList.self` under the root command registry.

If your main.swift uses grouped commands, ensure `MidiList` is reachable as:
- wub midi list

Example (conceptual):
```
subcommands: [
  ...,
  MidiList.self
]
```

This avoids guessing destination names during legacy automation.
