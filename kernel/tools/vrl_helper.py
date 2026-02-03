#!/usr/bin/env python3
"""
WUB VRL Helper (Optional)
Reads VRL YAML trigger spec and outputs:
- CSV mapping (phrase -> midi)
- sendmidi command lines per trigger
- Keyboard Maestro macro list (manual import guidance)

Usage:
  python3 kernel/tools/vrl_helper.py --in shared/specs/profiles/hvlien/voice/runtime/vrl_triggers.v1.yaml --out-dir out/

Notes:
- Requires PyYAML: pip3 install pyyaml
"""

from __future__ import annotations
import argparse
import csv
import os
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

def load_yaml(path: str) -> Dict[str, Any]:
    try:
        import yaml  # type: ignore
    except Exception as e:
        raise SystemExit(
            "PyYAML is required. Install with: pip3 install pyyaml\n"
            f"Import error: {e}"
        )
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)

@dataclass
class Trigger:
    trigger_id: str
    phrase: str
    midi_type: str
    cc: Optional[int] = None
    note: Optional[int] = None
    value: Optional[int] = None
    velocity: Optional[int] = None
    target: str = ""
    intent: str = ""

def normalize_target(t: Dict[str, Any]) -> str:
    # prefer macro/device/clip/track/scene/transport
    for k in ["macro","device","clip","track","scene","transport"]:
        if k in t and t[k]:
            return f"{k}:{t[k]}"
    return ""

def parse_triggers(doc: Dict[str, Any]) -> List[Trigger]:
    if doc.get("layer") != "vrl":
        raise SystemExit("Expected layer: vrl")
    tr = doc.get("triggers") or {}
    out: List[Trigger] = []
    for tid, body in tr.items():
        phrase = body.get("phrase","").strip()
        action = body.get("action") or {}
        midi_type = action.get("type","").strip()
        target = normalize_target(body.get("target") or {})
        intent = (body.get("intent") or "").strip()

        if midi_type == "midi_cc":
            out.append(Trigger(
                trigger_id=tid, phrase=phrase, midi_type="cc",
                cc=int(action.get("cc")), value=int(action.get("value")),
                target=target, intent=intent
            ))
        elif midi_type == "midi_note":
            vel = action.get("velocity", 127)
            out.append(Trigger(
                trigger_id=tid, phrase=phrase, midi_type="note",
                note=int(action.get("note")), velocity=int(vel),
                target=target, intent=intent
            ))
        else:
            raise SystemExit(f"Unknown midi type for {tid}: {midi_type}")
    return out

def write_csv(triggers: List[Trigger], path: str, midi_bus: str, channel: int) -> None:
    with open(path, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["trigger_id","phrase","midi_bus","channel","type","cc","value","note","velocity","target","intent"])
        for t in triggers:
            w.writerow([
                t.trigger_id, t.phrase, midi_bus, channel, t.midi_type,
                t.cc if t.cc is not None else "",
                t.value if t.value is not None else "",
                t.note if t.note is not None else "",
                t.velocity if t.velocity is not None else "",
                t.target, t.intent
            ])

def sendmidi_line(t: Trigger, midi_bus: str, channel: int) -> str:
    # sendmidi example: sendmidi dev "WUB_VOICE" ch 1 cc 14 96
    if t.midi_type == "cc":
        return f'sendmidi dev "{midi_bus}" ch {channel} cc {t.cc} {t.value}'
    return f'sendmidi dev "{midi_bus}" ch {channel} on {t.note} {t.velocity or 127}'

def write_sendmidi(triggers: List[Trigger], path: str, midi_bus: str, channel: int) -> None:
    lines = ["# sendmidi commands (one per trigger)", ""]
    for t in triggers:
        lines.append(f"# {t.trigger_id}: "{t.phrase}" -> {t.target} ({t.intent})")
        lines.append(sendmidi_line(t, midi_bus, channel))
        lines.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines).rstrip() + "\n")

def write_km_guide(triggers: List[Trigger], path: str, midi_bus: str, channel: int, group_name: str) -> None:
    md = []
    md.append("# Keyboard Maestro Macro List (Manual Import Guidance)")
    md.append("")
    md.append(f"**Group name:** `{group_name}`")
    md.append(f"**MIDI bus:** `{midi_bus}`  |  **Channel:** `{channel}`")
    md.append("")
    md.append("Create **one macro per trigger**. Each macro executes exactly one shell command (sendmidi).")
    md.append("")
    md.append("## Naming convention")
    md.append("Use a stable prefix so Voice Control can call these reliably:")
    md.append("")
    md.append("- `VRL::<trigger_id>`")
    md.append("")
    md.append("## Macro table")
    md.append("")
    md.append("| Macro Name | Voice Phrase | Shell Command | Target |")
    md.append("|---|---|---|---|")
    for t in triggers:
        cmd = sendmidi_line(t, midi_bus, channel).replace("|","\|")
        md.append(f"| `VRL::{t.trigger_id}` | "{t.phrase}" | `{cmd}` | {t.target} |")
    md.append("")
    md.append("## Voice Control mapping")
    md.append("For each trigger:")
    md.append("1. macOS Voice Control → Commands… → +")
    md.append("2. When I say: the phrase")
    md.append("3. Perform: run the matching KM macro")
    md.append("")
    md.append("## Acceptance test")
    md.append("Run each macro 10× from KM UI; confirm one MIDI event arrives on the bus each time.")
    md.append("")
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(md) + "\n")

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="inp", required=True, help="Input VRL YAML triggers file")
    ap.add_argument("--out-dir", dest="outdir", required=True, help="Output directory")
    ap.add_argument("--channel", type=int, default=1, help="MIDI channel 1-16 (default 1)")
    ap.add_argument("--group-name", default="WUB VRL", help="KM group name")
    args = ap.parse_args()

    doc = load_yaml(args.inp)
    midi_bus = doc.get("midi_bus") or "WUB_VOICE"
    channel = max(1, min(int(args.channel), 16))

    triggers = parse_triggers(doc)
    triggers.sort(key=lambda t: t.trigger_id)

    os.makedirs(args.outdir, exist_ok=True)

    csv_path = os.path.join(args.outdir, "vrl_runtime_triggers.csv")
    send_path = os.path.join(args.outdir, "sendmidi_commands.txt")
    km_path = os.path.join(args.outdir, "keyboard_maestro_macro_list.md")

    write_csv(triggers, csv_path, midi_bus, channel)
    write_sendmidi(triggers, send_path, midi_bus, channel)
    write_km_guide(triggers, km_path, midi_bus, channel, args.group_name)

    print("Wrote:")
    print(" -", csv_path)
    print(" -", send_path)
    print(" -", km_path)

if __name__ == "__main__":
    main()
