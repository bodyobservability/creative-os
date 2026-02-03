#!/usr/bin/env python3
import json
import sys
from pathlib import Path

try:
    import jsonschema
except Exception as exc:
    print(f"ERROR: jsonschema not available: {exc}")
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent
SCHEMA_DIR = ROOT / "specs" / "automation" / "schemas"
SPEC_ROOT = ROOT / "specs" / "automation"
RUNS_DIR = ROOT / "runs"

VALIDATION_TARGETS = [
    (SCHEMA_DIR / "controllers.v1.schema.json", SPEC_ROOT / "controllers" / "controllers.v1.json"),
    (SCHEMA_DIR / "inventory.v1.schema.json", SPEC_ROOT / "inventory" / "inventory.v1.json"),
    (SCHEMA_DIR / "pack_signatures.v1.schema.json", SPEC_ROOT / "recommendations" / "pack_signatures.v1.json"),
    (SCHEMA_DIR / "recommendations.v1.schema.json", SPEC_ROOT / "recommendations" / "recommendations.v1.json"),
    (SCHEMA_DIR / "substitutions.v1.schema.json", SPEC_ROOT / "substitutions" / "substitutions.v1.json"),
    (SCHEMA_DIR / "creative_os_setup_receipt.v1.schema.json", SPEC_ROOT / "receipts" / "creative_os_setup_receipt.sample.v1.json"),
]

def _validate(schema_path: Path, doc_path: Path, errors: list[str]) -> None:
    with schema_path.open("r", encoding="utf-8") as f:
        schema = json.load(f)
    with doc_path.open("r", encoding="utf-8") as f:
        doc = json.load(f)
    try:
        jsonschema.validate(instance=doc, schema=schema)
    except Exception as exc:
        errors.append(f"{doc_path}: {exc}")

def _latest_setup_receipt_path() -> Path | None:
    if not RUNS_DIR.exists():
        return None
    receipts = list(RUNS_DIR.glob("*/creative_os_setup_receipt.v1.json"))
    if not receipts:
        return None
    receipts.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return receipts[0]

errors = []
skipped = []
for schema_path, doc_path in VALIDATION_TARGETS:
    if not schema_path.exists():
        errors.append(f"missing schema: {schema_path}")
        continue
    if not doc_path.exists():
        skipped.append(f"missing doc: {doc_path}")
        continue
    _validate(schema_path, doc_path, errors)

latest_receipt = _latest_setup_receipt_path()
if latest_receipt is not None:
    schema_path = SCHEMA_DIR / "creative_os_setup_receipt.v1.schema.json"
    if schema_path.exists():
        _validate(schema_path, latest_receipt, errors)
    else:
        errors.append(f"missing schema: {schema_path}")
else:
    skipped.append("no emitted setup receipts found under runs/*/creative_os_setup_receipt.v1.json")

if errors:
    print("Schema validation failed:")
    for err in errors:
        print(f"- {err}")
    sys.exit(1)

if skipped:
    print("Schema validation skipped:")
    for item in skipped:
        print(f"- {item}")

print("OK: schema validation passed")
