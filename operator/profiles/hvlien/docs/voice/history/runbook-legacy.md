# legacy Runbook — Create Ableton Assets

## Inputs
- legacy triggers (phrases → MIDI CC/Note)
- legacy runtime bridge (Voice → KM → sendmidi → WUB_VOICE)
- legacy Ableton mapping (this is what you're implementing)
- `rack.macros` region configured (for verification)

## Step 1 — Ensure WUB_VOICE exists
- Audio MIDI Setup → IAC Driver → Device online → Port `WUB_VOICE`

## Step 2 — Ensure legacy works (quick)
- Speak "wub up" and confirm Ableton MIDI indicator flashes (or MIDI Monitor sees CC14)

## Step 3 — Build assets using the voice recipe
Open:
- `shared/specs/profiles/hvlien/voice/runtime/build_assets.voice_recipe.v1.yaml`

Run it once to:
- create the Control Rack with ABI macro names
- map CC14 and CC21 in MIDI Map Mode
- save the rack preset: `HVLIEN_VRL_ControlRack`
- save the template set: `HVLIEN_BASS_TEMPLATE_VRL`

## Step 4 — Verify assets via v4 apply
Run:
```bash
wub apply --plan shared/specs/profiles/hvlien/voice/runtime/verify_assets.plan.v1.json --allow-cgevent
```

If OCR fails on macro labels:
- tighten `rack.macros` region
- run `wub ocr-dump --region rack.macros`

## Step 5 — Commit assets (manual)
- Copy the saved `.adg` and `.als` files into your repo asset folder (if you want them versioned)
- Or keep them in Ableton User Library and rely on verification + naming.
