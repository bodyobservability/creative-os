#!/usr/bin/env python3
"""Status: Count bundles by economic_owner and treatment.

Usage:
  python3 accounting/scripts/status.py

Reads:
  accounting/data/2025/bundles/<id>/extracted/extracted_metadata.json
"""

import json
import pathlib
from collections import Counter, defaultdict

BUNDLES_DIR = pathlib.Path("accounting/data/2025/bundles")

def norm(v):
    return str(v or "").strip().lower()

def main():
    owners = Counter()
    treatments = Counter()
    owner_treatment = Counter()
    missing = 0
    total = 0

    if not BUNDLES_DIR.exists():
        print(f"No bundles directory found at {BUNDLES_DIR}")
        return

    for b in sorted([p for p in BUNDLES_DIR.iterdir() if p.is_dir()]):
        meta_path = b / "extracted" / "extracted_metadata.json"
        if not meta_path.exists():
            missing += 1
            continue
        total += 1
        meta = json.loads(meta_path.read_text())
        o = norm(meta.get("economic_owner", "")) or "∅"
        t = norm(meta.get("treatment", "")) or "∅"
        owners[o] += 1
        treatments[t] += 1
        owner_treatment[(o, t)] += 1

    print("Accounting Status (2025)")
    print(f"- bundles with metadata: {total}")
    print(f"- bundles missing metadata: {missing}")
    print("\nBy economic_owner:")
    for k,v in owners.most_common():
        print(f"  {k:16} {v}")
    print("\nBy treatment:")
    for k,v in treatments.most_common():
        print(f"  {k:16} {v}")
    print("\nBy (economic_owner, treatment):")
    for (o,t),v in owner_treatment.most_common():
        print(f"  ({o:14}, {t:7}) {v}")

if __name__ == "__main__":
    main()
