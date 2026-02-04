#!/usr/bin/env python3
"""CI Check: Ensure economic_owner is set for every bundle after triage.

Fail conditions:
- Any bundle missing extracted/extracted_metadata.json
- Any bundle missing economic_owner or has empty/tbd/unknown
- (Optional) economic_owner not in allowed set

Usage:
  python3 accounting/scripts/ci_check_economic_owner.py
"""

import json
import pathlib
import sys
from typing import Any, Dict

BUNDLES_DIR = pathlib.Path("accounting/2025/bundles")
ALLOWED = {"personal", "sole_proprietor", "sole_prop", "c_corp", "corp"}
BAD = {"", "tbd", "unknown", "unset", "none"}

def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

def load_json(p: pathlib.Path) -> Dict[str, Any]:
    try:
        return json.loads(p.read_text())
    except Exception as e:
        die(f"Failed to read JSON {p}: {e}")
    raise RuntimeError

def norm(v: Any) -> str:
    return str(v or "").strip().lower()

def main() -> None:
    if not BUNDLES_DIR.exists():
        die(f"Bundles directory not found: {BUNDLES_DIR}")

    failures = []
    missing_meta = 0

    for bundle_dir in sorted([p for p in BUNDLES_DIR.iterdir() if p.is_dir()]):
        meta_path = bundle_dir / "extracted" / "extracted_metadata.json"
        if not meta_path.exists():
            missing_meta += 1
            failures.append(f"{bundle_dir.name}: missing extracted_metadata.json")
            continue

        meta = load_json(meta_path)
        owner = norm(meta.get("economic_owner", ""))

        if owner in BAD:
            failures.append(f"{bundle_dir.name}: economic_owner is '{owner or '∅'}'")
            continue

        if owner not in { "personal", "sole_proprietor", "sole_prop", "c_corp", "corp" }:
            failures.append(f"{bundle_dir.name}: economic_owner '{owner}' not in allowed set")
            continue

    if failures:
        print("❌ CI CHECK FAILED: economic_owner not fully classified")
        for f in failures[:200]:
            print(" - " + f)
        if len(failures) > 200:
            print(f" ... and {len(failures)-200} more")
        sys.exit(2)

    print("✅ CI CHECK PASSED: all bundles have economic_owner set")
    if missing_meta:
        print(f"Note: {missing_meta} bundles were missing metadata (would have failed).")

if __name__ == "__main__":
    main()
