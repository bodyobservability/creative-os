#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

shasum -a 256 -c checksums/specs_sha256.txt
shasum -a 256 -c checksums/docs_sha256.txt
shasum -a 256 -c checksums/ableton_sha256.txt
shasum -a 256 -c checksums/ai_sha256.txt
shasum -a 256 -c checksums/controllers_sha256.txt
shasum -a 256 -c checksums/logic_sha256.txt

echo "OK: checksums verified"
