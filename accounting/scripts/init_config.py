#!/usr/bin/env python3
"""Initialize local config files from templates, refusing overwrite.

Usage:
  python3 accounting/scripts/init_config.py

Copies:
  CONFIG/corp_payment_fingerprints.template.json -> CONFIG/corp_payment_fingerprints.json
"""

import shutil
from pathlib import Path
import sys

src = Path("CONFIG/corp_payment_fingerprints.template.json")
dst = Path("CONFIG/corp_payment_fingerprints.json")

def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

def main():
    if not src.exists():
        die(f"Missing template: {src}")
    if dst.exists():
        die(f"Refusing to overwrite existing config: {dst}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    print(f"✅ Created {dst} from template. Edit it with your corp card last4 / billing tokens.")

if __name__ == "__main__":
    main()
