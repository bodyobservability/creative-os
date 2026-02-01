# v9.3.2 — True Automation Runbook

## Preconditions
- Ableton open, set loaded, BassLead track exists
- Browser visible, Device view visible
- IAC Driver online, port named: WUB_VOICE
- `rack.macros` region set and OCR works (`wub ocr-dump --region rack.macros`)

## Run
```bash
wub apply --plan profiles/hvlien/specs/voice_runtime/v9_3_2_build_assets.plan.v1.json --allow-cgevent
```

## Outputs (Ableton saves)
- Rack preset: HVLIEN_VRL_ControlRack_v9_3_2
- Set template: HVLIEN_BASS_TEMPLATE_VRL_v9_3_2

If the plan fails on renaming:
- tighten rack.macros region
- adjust OCR target "Macro 1" etc in plan (Ableton sometimes labels differently)
