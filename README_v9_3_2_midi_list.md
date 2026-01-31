# HVLIEN v9.3.2 — MIDI List Command

This bundle adds:
- `hvlien midi list`

Purpose:
- Show the exact CoreMIDI destination names as seen by the system.
- Use this to confirm the substring you should pass as `midi_dest` in apply plans (e.g. HVLIEN_VOICE).

## Usage
```bash
hvlien midi list
```

## Wiring
Add `MidiList.self` under the root command registry.

If your main.swift uses grouped commands, ensure `MidiList` is reachable as:
- hvlien midi list

Example (conceptual):
```
subcommands: [
  ...,
  MidiList.self
]
```

This avoids guessing destination names during v9.3.2 automation.
