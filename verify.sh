#!/usr/bin/env bash
set -euo pipefail
# Run minimal smoke checks that bundle support CLI exists.
python3 -m creative_os.cli bundle --help >/dev/null
python3 -m creative_os.cli bundle import --help >/dev/null
python3 -m creative_os.cli bundle list --help >/dev/null
echo "OK: creative-os bundle CLI available"
