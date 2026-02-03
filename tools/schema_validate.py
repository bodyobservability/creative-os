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

VALIDATION_TARGETS = [
    (SCHEMA_DIR / "controllers.v1.schema.json", SPEC_ROOT / "controllers" / "controllers.v1.json"),
    (SCHEMA_DIR / "inventory.v1.schema.json", SPEC_ROOT / "inventory" / "inventory.v1.json"),
    (SCHEMA_DIR / "pack_signatures.v1.schema.json", SPEC_ROOT / "recommendations" / "pack_signatures.v1.json"),
    (SCHEMA_DIR / "recommendations.v1.schema.json", SPEC_ROOT / "recommendations" / "recommendations.v1.json"),
    (SCHEMA_DIR / "substitutions.v1.schema.json", SPEC_ROOT / "substitutions" / "substitutions.v1.json"),
]

errors = []
skipped = []
for schema_path, doc_path in VALIDATION_TARGETS:
    if not schema_path.exists():
        errors.append(f"missing schema: {schema_path}")
        continue
    if not doc_path.exists():
        skipped.append(f"missing doc: {doc_path}")
        continue
    with schema_path.open("r", encoding="utf-8") as f:
        schema = json.load(f)
    with doc_path.open("r", encoding="utf-8") as f:
        doc = json.load(f)
    try:
        jsonschema.validate(instance=doc, schema=schema)
    except Exception as exc:
        errors.append(f"{doc_path}: {exc}")

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
