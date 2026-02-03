#!/usr/bin/env python3
import argparse
import json
import sys
from pathlib import Path
from typing import Optional

try:
    import jsonschema
except Exception as exc:
    print(f"ERROR: jsonschema not available: {exc}")
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent.parent
SCHEMA_DIR = ROOT / "shared" / "specs" / "automation" / "schemas"
SPEC_ROOT = ROOT / "shared" / "specs" / "automation"
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

def _latest_setup_receipt_path() -> Optional[Path]:
    if not RUNS_DIR.exists():
        return None
    receipts = list(RUNS_DIR.glob("*/creative_os_setup_receipt.v1.json"))
    if not receipts:
        return None
    receipts.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    return receipts[0]

def _validate_targets(targets: list[tuple[Path, Path]]) -> int:
    errors: list[str] = []
    skipped: list[str] = []
    for schema_path, doc_path in targets:
        if not schema_path.exists():
            errors.append(f"missing schema: {schema_path}")
            continue
        if not doc_path.exists():
            skipped.append(f"missing doc: {doc_path}")
            continue
        _validate(schema_path, doc_path, errors)

    if errors:
        print("Schema validation failed:")
        for err in errors:
            print(f"- {err}")
        return 1

    if skipped:
        print("Schema validation skipped:")
        for item in skipped:
            print(f"- {item}")

    print("OK: schema validation passed")
    return 0


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate JSON instances against JSON schemas.")
    parser.add_argument("--schema", type=str, help="Path to schema JSON file.")
    parser.add_argument("--instance", type=str, help="Path to instance JSON file.")
    parser.add_argument("--instances", type=str, help="Glob of instance JSON files to validate.")
    return parser.parse_args()


def _main() -> int:
    args = _parse_args()

    if args.schema or args.instance or args.instances:
        if not args.schema:
            print("ERROR: --schema is required when using instance validation.")
            return 2
        schema_path = Path(args.schema)
        if args.instance and args.instances:
            print("ERROR: Use --instance or --instances, not both.")
            return 2
        if args.instance:
            return _validate_targets([(schema_path, Path(args.instance))])
        if args.instances:
            instance_paths = [Path(p) for p in sorted(Path(".").glob(args.instances))]
            if not instance_paths:
                print(f"ERROR: No instances matched glob: {args.instances}")
                return 2
            return _validate_targets([(schema_path, p) for p in instance_paths])
        print("ERROR: --instance or --instances is required when using --schema.")
        return 2

    # Default behavior: validate canonical spec set.
    errors: list[str] = []
    skipped: list[str] = []
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
        return 1

    if skipped:
        print("Schema validation skipped:")
        for item in skipped:
            print(f"- {item}")

    print("OK: schema validation passed")
    return 0


if __name__ == "__main__":
    sys.exit(_main())
