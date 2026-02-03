#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

mkdir -p checksums
OPERATOR_ROOT="operator"
OPERATOR_NOTES="${OPERATOR_ROOT}/notes"
OPERATOR_PROFILES="${OPERATOR_ROOT}/profiles"
OPERATOR_PACKS="${OPERATOR_ROOT}/packs"

# Specs + contracts (core + profile-specific)
( find shared/specs -type f -print0; find shared/contracts -type f -print0 ) | LC_ALL=C sort -z | xargs -0 shasum -a 256 > checksums/specs_sha256.txt

# Docs (README + notes + profile docs)
( printf "%s\0" README.md; find "${OPERATOR_NOTES}" -type f ! -path "${OPERATOR_NOTES}/LOCAL_CONFIG.json" ! -path "${OPERATOR_NOTES}/WUB_CONFIG.json" -print0; find "${OPERATOR_PROFILES}" -path "*/notes/*" -type f -print0; find docs -type f -print0; find "${OPERATOR_PROFILES}" -path "*/docs/*" -type f -print0 ) | LC_ALL=C sort -z | xargs -0 shasum -a 256 > checksums/docs_sha256.txt

# Ableton artifacts (core + pack-specific)
( (find ableton -type f -print0 2>/dev/null || true); find "${OPERATOR_PACKS}" -path "*/ableton/*" -type f -print0 ) | LC_ALL=C sort -z | xargs -0 shasum -a 256 > checksums/ableton_sha256.txt

# AI shared/specs/pipelines (text)
find ai -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > checksums/ai_sha256.txt

# Controllers
find controllers -type f -print0 | LC_ALL=C sort -z | xargs -0 shasum -a 256 > checksums/controllers_sha256.txt

echo "Wrote:"
echo "  checksums/specs_sha256.txt"
echo "  checksums/docs_sha256.txt"
echo "  checksums/ableton_sha256.txt"
echo "  checksums/ai_sha256.txt"
echo "  checksums/controllers_sha256.txt"
