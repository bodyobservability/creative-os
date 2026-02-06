#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
apply.sh --target <dir> [--force]

Overlays this bundle into <dir> and runs verify.sh.

EOF
}

TARGET=""
FORCE="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="${2:-}"; shift 2;;
    --force) FORCE="1"; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1" >&2; usage; exit 2;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "ERROR: --target is required" >&2
  usage
  exit 2
fi

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIP_FILE="$(ls -1 "${BUNDLE_DIR}"/*.zip 2>/dev/null | head -n 1 || true)"
MANIFEST_FILE="${BUNDLE_DIR}/bundle_manifest.v1.json"

if [[ -z "$ZIP_FILE" ]]; then
  echo "ERROR: No .zip found next to apply.sh" >&2
  exit 1
fi

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"

LOG_DIR="${TARGET}/.cos_apply_logs"
mkdir -p "$LOG_DIR"
TS="$(date -u +"%Y%m%dT%H%M%SZ")"
LOG_FILE="${LOG_DIR}/${TS}_apply.log"

echo "== cos bundle apply (creative-os bundle support) ==" | tee "$LOG_FILE"
echo "zip: ${ZIP_FILE}" | tee -a "$LOG_FILE"
echo "manifest: ${MANIFEST_FILE}" | tee -a "$LOG_FILE"
echo "target: ${TARGET}" | tee -a "$LOG_FILE"
echo "force: ${FORCE}" | tee -a "$LOG_FILE"

if [[ "$FORCE" != "1" ]]; then
  # refuse overwrite if target not empty
  if [[ -n "$(ls -A "$TARGET" 2>/dev/null || true)" ]]; then
    echo "Target not empty; re-run with --force to overwrite." | tee -a "$LOG_FILE"
    exit 3
  fi
fi

echo "Unzipping overlay..." | tee -a "$LOG_FILE"
unzip -o -q "$ZIP_FILE" -d "$TARGET"
echo "Unzip complete." | tee -a "$LOG_FILE"

echo "Running verify..." | tee -a "$LOG_FILE"
bash "${TARGET}/verify.sh" | tee -a "$LOG_FILE"

echo "OK: applied + verified" | tee -a "$LOG_FILE"
echo "log: ${LOG_FILE}" | tee -a "$LOG_FILE"
