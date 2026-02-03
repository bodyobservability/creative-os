#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p checksums

# Specs (core + profile-specific)
( find specs -type f -print0; find profiles -path "*/specs/*" -type f -print0 ) | sort -z | xargs -0 shasum -a 256 > checksums/specs_sha256.txt

# Docs (README + notes + profile docs)
( printf "%s\0" README.md; find notes -type f ! -path "notes/LOCAL_CONFIG.json" ! -path "notes/WUB_CONFIG.json" -print0; find profiles -path "*/notes/*" -type f -print0; find docs -type f -print0; find profiles -path "*/docs/*" -type f -print0 ) | sort -z | xargs -0 shasum -a 256 > checksums/docs_sha256.txt

# Ableton artifacts (core + pack-specific)
( (find ableton -type f -print0 2>/dev/null || true); find packs -path "*/ableton/*" -type f -print0 ) | sort -z | xargs -0 shasum -a 256 > checksums/ableton_sha256.txt

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
