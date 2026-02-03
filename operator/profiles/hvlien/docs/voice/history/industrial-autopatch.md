# HVLIEN legacy Industrial Autopatch

This autopatch enables execution of legacy true automation plans by adding:

- PlanModels.swift: MIDI fields on PlanAction (`midi_dest`, `channel`, `cc`, `value`, `note`, `velocity`) + OR assert tokens.
- ApplyRunner.swift: support for `send_midi_cc` and `send_midi_note` using CoreMIDI (`MidiSend`).

## Apply order
1) Apply `HVLIEN_true_automation_bundle.zip` (plan + runbook)
2) Apply this autopatch zip (overwrites PlanModels.swift and ApplyRunner.swift)
3) Build CLI
4) Run apply plan:
   wub apply --plan shared/specs/profiles/hvlien/voice/runtime/build_assets.plan.v1.json --allow-cgevent

## Notes
- MIDI destination matching uses `midi_dest` as a substring to match a CoreMIDI destination name.
  For IAC, "WUB_VOICE" is recommended.
