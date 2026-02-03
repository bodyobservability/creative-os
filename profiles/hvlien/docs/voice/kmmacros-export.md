# WUB Keyboard Maestro Export

## Version
Version: current

## History
- (none)


This bundle provides a generator that produces a **Keyboard Maestro `.kmmacros`** file from the v9.1 trigger spec.

## Requirements
- Keyboard Maestro (Mac)
- `sendmidi` installed and available on PATH
- Python 3 + PyYAML:
  ```bash
  pip3 install pyyaml
  ```

## Generate the KM export
```bash
python3 tools/generate_kmmacros.py \
  --in profiles/hvlien/specs/voice/runtime/vrl_triggers.v1.yaml \
  --out WUB_VRL.kmmacros \
  --group-name "WUB VRL" \
  --channel 1
```

## Import into Keyboard Maestro
1) Open Keyboard Maestro  
2) File → Import…  
3) Select `WUB_VRL.kmmacros`  
4) Confirm a macro group appears with macros named `VRL::<trigger_id>`

## Voice Control binding
For each phrase in v9.1:
- Voice Control → Commands… → +  
- When I say: `<phrase>`  
- Perform: Run Keyboard Maestro macro: `VRL::<trigger_id>`

## Notes
Keyboard Maestro’s plist export format is not publicly documented. This generator uses a minimal structure that is commonly importable.
If import fails, we can adjust the export structure based on the KM error message.
