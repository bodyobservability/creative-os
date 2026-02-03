# Runtime Mapping Validator

## Version
Version: v9.4

## History
- (none)


Adds a validator that produces a receipt proving your Ableton set is *ready* for v9 runtime triggers.

Command:
```bash
wub vrl validate --mapping profiles/hvlien/specs/voice/runtime/vrl_mapping.v1.yaml --regions tools/automation/swift-cli/config/regions.v1.json
```

What it checks (best-effort):
- CoreMIDI destination exists matching the mapping `midi.bus` (default: WUB_VOICE)
- Required regions exist: tracks.list, device.chain, rack.macros
- Track names referenced in mapping exist in tracks.list (OCR)
- ABI macro labels exist in rack.macros (OCR)
- Clip names referenced in mapping are visible (best-effort; warns if not visible)

Artifacts (when --dump enabled):
- frame_full.png
- cropped region PNGs + OCR JSON dumps

Output:
- runs/<run_id>/vrl_mapping_receipt.v1.json
