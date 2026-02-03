#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCHEMA="$ROOT_DIR/shared/contracts/operator-persona/persona.manifest.schema.json"
MANIFEST_DIR="$ROOT_DIR/shared/contracts/operator-persona"

MANIFESTS=()
while IFS= read -r manifest; do
  MANIFESTS+=("$manifest")
done < <(find "$MANIFEST_DIR" -maxdepth 1 -type f -name "*.manifest.json" -print | sort)

if [[ ! -f "$SCHEMA" ]]; then
  echo "ERROR: Schema not found: $SCHEMA" >&2
  exit 1
fi

if [[ ${#MANIFESTS[@]} -eq 0 ]]; then
  echo "ERROR: No persona manifests found under: $MANIFEST_DIR" >&2
  exit 1
fi

echo "Validating operator persona manifests"
echo "  Schema:   ${SCHEMA#$ROOT_DIR/}"
echo "  Manifests:"
for m in "${MANIFESTS[@]}"; do
  echo "    - ${m#$ROOT_DIR/}"
done
echo

PY_VALIDATOR="$ROOT_DIR/kernel/tools/schema_validate.py"

FAILED=0

for manifest in "${MANIFESTS[@]}"; do
  echo "-> Validating ${manifest#$ROOT_DIR/}"

  if [[ -f "$PY_VALIDATOR" ]]; then
    if python3 "$PY_VALIDATOR" --schema "$SCHEMA" --instance "$manifest"; then
      echo "  OK (kernel/tools/schema_validate.py)"
      continue
    fi
  fi

  echo "  ERROR: Unable to validate manifest with kernel/tools/schema_validate.py" >&2
  FAILED=1
done

if [[ "$FAILED" -ne 0 ]]; then
  echo
  echo "Manifest validation failed." >&2
  exit 1
fi

echo
echo "All persona manifests validated successfully."
