#!/usr/bin/env python3
"""
WUB VRL — Keyboard Maestro .kmmacros Export Generator

Reads VRL YAML trigger spec and generates a Keyboard Maestro Macro Group export (.kmmacros)
with one macro per trigger, each running exactly one sendmidi shell command.

Usage:
  pip3 install pyyaml
  python3 tools/generate_kmmacros.py \
    --in profiles/hvlien/specs/voice/runtime/vrl_triggers.v1.yaml \
    --out WUB_VRL.kmmacros \
    --group-name "WUB VRL" \
    --channel 1

Notes:
- Keyboard Maestro's internal plist format is not publicly documented; this generator uses a widely compatible structure.
- If KM refuses import, open the generated file in a text editor and confirm it is valid XML plist.
"""

from __future__ import annotations
import argparse
import os
import uuid
import plistlib
from typing import Any, Dict, List

def load_yaml(path: str) -> Dict[str, Any]:
    import yaml  # type: ignore
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)

def sendmidi_line(midi_type: str, midi_bus: str, channel: int, cc: int | None, value: int | None, note: int | None, velocity: int | None) -> str:
    if midi_type == "midi_cc":
        return f'sendmidi dev "{midi_bus}" ch {channel} cc {cc} {value}'
    vel = velocity if velocity is not None else 127
    return f'sendmidi dev "{midi_bus}" ch {channel} on {note} {vel}'

def km_uid() -> str:
    # KM typically uses UUID strings
    return str(uuid.uuid4()).upper()

def make_shell_action(script: str) -> Dict[str, Any]:
    return {
        "MacroActionType": "ExecuteShellScript",
        "Text": script,
        "UseText": True,
        "Shell": "/bin/zsh",
        "TrimResults": True,
        "DisplayKind": "None"
    }

def make_macro(name: str, script: str) -> Dict[str, Any]:
    return {
        "Name": name,
        "UID": km_uid(),
        "IsActive": True,
        "Actions": [make_shell_action(script)],
        "Triggers": [],
    }

def make_group(name: str, macros: List[Dict[str, Any]]) -> Dict[str, Any]:
    return {
        "Name": name,
        "UID": km_uid(),
        "IsActive": True,
        "Macros": macros,
    }

def make_export(groups: List[Dict[str, Any]]) -> Dict[str, Any]:
    # Keyboard Maestro exports commonly wrap MacroGroups at top-level
    return {
        "MacroGroups": groups,
        "Version": "1.0"
    }

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True)
    ap.add_argument("--out", dest="out", required=True)
    ap.add_argument("--group-name", default="WUB VRL")
    ap.add_argument("--channel", type=int, default=1)
    args = ap.parse_args()

    doc = load_yaml(args.inp)
    midi_bus = doc.get("midi_bus") or "WUB_VOICE"
    channel = max(1, min(int(args.channel), 16))

    triggers = doc.get("triggers") or {}
    macros: List[Dict[str, Any]] = []

    for trigger_id in sorted(triggers.keys()):
        t = triggers[trigger_id]
        phrase = (t.get("phrase") or "").strip()
        action = t.get("action") or {}
        ttype = (action.get("type") or "").strip()

        if ttype not in ("midi_cc", "midi_note"):
            raise SystemExit(f"Unsupported action.type for {trigger_id}: {ttype}")

        cc = action.get("cc")
        value = action.get("value")
        note = action.get("note")
        velocity = action.get("velocity", 127)

        script = sendmidi_line(ttype, midi_bus, channel, cc, value, note, velocity)
        macro_name = f"VRL::{trigger_id}"
        m = make_macro(macro_name, script)
        # Add comment block in macro for human traceability (KM accepts arbitrary keys; safe to include)
        m["Notes"] = f'phrase: "{phrase}"\nintent: {t.get("intent","")}'
        macros.append(m)

    group = make_group(args.group_name, macros)
    export = make_export([group])

    with open(args.out, "wb") as f:
        plistlib.dump(export, f, fmt=plistlib.FMT_XML, sort_keys=True)

    print("Wrote:", args.out)
    print("Macros:", len(macros))
    print("MIDI bus:", midi_bus, "channel:", channel)

if __name__ == "__main__":
    main()
