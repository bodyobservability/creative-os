# HVLIEN Voice Compile Card

**Script:** {{script_name}}  
**Display Profile:** {{display_profile}}  
**Ableton:** {{ableton_version}} / Theme: {{ableton_theme}}  
**Goal:** {{goal}}

---

## Assumptions
{{assumptions}}

---

## Steps (say / dictate / click)
{{steps}}

---

## After the voice compile (v4 verification)
```bash
wub safety --modal-test detect --anchors-pack {{anchors_pack}} --allow-ocr-fallback
wub apply --plan profiles/hvlien/specs/voice/verify/verify_abi.plan.v1.json --anchors-pack {{anchors_pack}}
```

Artifacts:
- runs/<run_id>/receipt.v1.json
- runs/<run_id>/trace.v1.json
- runs/<run_id>/failures/...

---

## Notes
- Voice Control is a compile step, not runtime control.
- Macro ABI is canonical; do not rename macros.
