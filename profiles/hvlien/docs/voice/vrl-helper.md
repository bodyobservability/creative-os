# WUB Optional Helper

## Version
Version: v9.2.1

## History
- (none)


This helper reads the v9.1 trigger spec YAML and produces three outputs:

1) **CSV mapping**
2) **sendmidi command lines**
3) **Keyboard Maestro macro list** (manual import guidance)

## Requirements
- Python 3
- PyYAML:
  ```bash
  pip3 install pyyaml
  ```

## Usage
```bash
python3 tools/vrl_helper.py   --in profiles/hvlien/specs/voice/runtime/vrl_triggers.v1.yaml   --out-dir out_vrl_helper   --channel 1   --group-name "WUB VRL"
```

## Outputs
- `out_vrl_helper/vrl_runtime_triggers.csv`
- `out_vrl_helper/sendmidi_commands.txt`
- `out_vrl_helper/keyboard_maestro_macro_list.md`

## Notes
- This helper does **not** generate a KM `.kmmacros` export (that is v9.2.2+).
- It exists to prevent manual transcription errors.
