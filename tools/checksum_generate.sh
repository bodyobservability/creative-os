#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p checksums

# Specs
find specs -type f -print0 | sort -z | xargs -0 shasum -a 256 > checksums/specs_sha256.txt

# Docs (README + notes)
( printf "%s\0" README.md; find notes -type f -print0; find docs -type f -print0 ) | sort -z | xargs -0 shasum -a 256 > checksums/docs_sha256.txt

# Ableton artifacts
find ableton -type f -print0 | sort -z | xargs -0 shasum -a 256 > checksums/ableton_sha256.txt

# AI specs/pipelines (text)
find ai -type f -print0 | sort -z | xargs -0 shasum -a 256 > checksums/ai_sha256.txt

# Controllers
find controllers -type f -print0 | sort -z | xargs -0 shasum -a 256 > checksums/controllers_sha256.txt

echo "Wrote:"
echo "  checksums/specs_sha256.txt"
echo "  checksums/docs_sha256.txt"
echo "  checksums/ableton_sha256.txt"
echo "  checksums/ai_sha256.txt"
echo "  checksums/controllers_sha256.txt"
