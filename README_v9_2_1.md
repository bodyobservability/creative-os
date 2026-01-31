# HVLIEN v9.2.1 Optional Helper

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
python3 tools/v9_2_1_vrl_helper.py   --in specs/voice_runtime/voice_runtime_triggers.v9.yaml   --out-dir out_v9_2_1   --channel 1   --group-name "HVLIEN VRL v9"
```

## Outputs
- `out_v9_2_1/v9_runtime_triggers.csv`
- `out_v9_2_1/sendmidi_commands.txt`
- `out_v9_2_1/keyboard_maestro_macro_list.md`

## Notes
- This helper does **not** generate a KM `.kmmacros` export (that is v9.2.2+).
- It exists to prevent manual transcription errors.
