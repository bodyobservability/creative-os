# v9.3.1 Runbook — Create Ableton Assets

## Inputs
- v9.1 triggers (phrases → MIDI CC/Note)
- v9.2 runtime bridge (Voice → KM → sendmidi → HVLIEN_VOICE)
- v9.3 Ableton mapping (this is what you're implementing)
- `rack.macros` region configured (for verification)

## Step 1 — Ensure HVLIEN_VOICE exists
- Audio MIDI Setup → IAC Driver → Device online → Port `HVLIEN_VOICE`

## Step 2 — Ensure v9.2 works (quick)
- Speak "wub up" and confirm Ableton MIDI indicator flashes (or MIDI Monitor sees CC14)

## Step 3 — Build assets using the voice recipe
Open:
- `specs/voice_runtime/v9_3_1_build_assets.voice_recipe.yaml`

Run it once to:
- create the Control Rack with ABI macro names
- map CC14 and CC21 in MIDI Map Mode
- save the rack preset: `HVLIEN_VRL_ControlRack_v9_3_1`
- save the template set: `HVLIEN_BASS_TEMPLATE_VRL_v9_3_1`

## Step 4 — Verify assets via v4 apply
Run:
```bash
hvlien apply --plan specs/voice_runtime/v9_3_1_verify_assets.plan.v1.json --allow-cgevent
```

If OCR fails on macro labels:
- tighten `rack.macros` region
- run `hvlien ocr-dump --region rack.macros`

## Step 5 — Commit assets (manual)
- Copy the saved `.adg` and `.als` files into your repo asset folder (if you want them versioned)
- Or keep them in Ableton User Library and rely on verification + naming.
