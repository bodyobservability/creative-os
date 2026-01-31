# v9.3.2 True Automation Notes

This bundle includes a v4 Apply plan that automates:
- insert Instrument Rack
- rename macros to ABI canonical names
- MIDI-map Motion and Tone macro jumps by sending MIDI CC values directly
- save rack preset and template set

## Requires
- `rack.macros` region configured and OCR readable
- IAC Driver port online: `HVLIEN_VOICE`
- ApplyRunner must support new actions:
  - `send_midi_cc` with fields: midi_dest, channel, cc, value
  - (optional) `send_midi_note`

If your current ApplyRunner does not support these actions, you will need a small patch to Add perform() cases.
I can ship that autopatch next once you share which ApplyRunner variant you currently use (industrial vs minimal).
