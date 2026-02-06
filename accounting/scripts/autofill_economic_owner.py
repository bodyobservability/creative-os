#!/usr/bin/env python3
"""Creative-OS Accounting: Autofill economic_owner from corp payment fingerprints

Adds robust, deterministic autofill for:
- economic_owner = c_corp

Based on:
- card_last4 (primary signal)
- optional brand / billing_zip
- optional billing address/name tokens

Why separate script?
- Classification is a durable decision, not an export-time inference.
- Writes append-only decision records.
- Idempotent.

Usage
  python3 accounting/scripts/autofill_economic_owner.py
  python3 accounting/scripts/autofill_economic_owner.py --dry-run

Dry-run mode:
- shows matches
- writes nothing
- does not modify metadata

Config
- Copy CONFIG/corp_payment_fingerprints.template.json -> CONFIG/corp_payment_fingerprints.json
- Fill in corp card last4 + optional billing tokens (never full card numbers)
"""

import argparse
import json
import pathlib
import sys
from datetime import datetime
from typing import Any, Dict, List

YEAR = "2025"
BUNDLES_DIR = pathlib.Path("accounting/data/2025/bundles")
CONFIG_PATH = pathlib.Path("CONFIG/corp_payment_fingerprints.json")
DECISION_FILENAME = "auto_owner_from_payment.json"

def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

def load_json(path: pathlib.Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text())
    except Exception as e:
        die(f"Failed to read JSON {path}: {e}")
    raise RuntimeError

def norm(s: Any) -> str:
    return str(s or "").strip().lower()

def contains_any(hay: str, needles: List[str]) -> bool:
    h = hay.lower()
    return any(n.lower() in h for n in needles if n)

def get_payment(meta: Dict[str, Any]) -> Dict[str, Any]:
    p = meta.get("payment", {}) if isinstance(meta.get("payment", {}), dict) else {}
    return {
        "card_last4": meta.get("card_last4", p.get("card_last4", "")),
        "card_brand": meta.get("card_brand", p.get("card_brand", "")),
        "billing_zip": meta.get("billing_zip", p.get("billing_zip", "")),
        "billing_name": meta.get("billing_name", p.get("billing_name", "")),
        "billing_address": meta.get("billing_address", p.get("billing_address", "")),
    }

def strong_match_by_last4(payment: Dict[str, Any], corp_card: Dict[str, Any], policy: Dict[str, Any]) -> bool:
    if not payment.get("card_last4"):
        return False
    if norm(payment["card_last4"]) != norm(corp_card.get("last4", "")):
        return False

    if policy.get("require_brand_if_present") and payment.get("card_brand") and corp_card.get("brand"):
        if norm(payment["card_brand"]) != norm(corp_card["brand"]):
            return False
    if policy.get("require_billing_zip_if_present") and payment.get("billing_zip") and corp_card.get("billing_zip"):
        if norm(payment["billing_zip"]) != norm(corp_card["billing_zip"]):
            return False
    return True

def match_by_address(payment: Dict[str, Any], corp_addr_needles: List[str]) -> bool:
    addr_blob = " ".join([payment.get("billing_name",""), payment.get("billing_address","")]).strip()
    if not addr_blob:
        return False
    return contains_any(addr_blob, corp_addr_needles)

def should_overwrite_existing_owner(existing: str) -> bool:
    e = norm(existing)
    return e in ("", "tbd", "unknown", "unset", "none")

def write_decision(bundle_dir: pathlib.Path, decision: Dict[str, Any]) -> None:
    ddir = bundle_dir / "decisions"
    ddir.mkdir(exist_ok=True)
    (ddir / DECISION_FILENAME).write_text(json.dumps(decision, indent=2) + "\n")

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="Show matches but do not write decisions or modify metadata")
    args = ap.parse_args()

    if not CONFIG_PATH.exists():
        die(f"Missing config: {CONFIG_PATH}. Copy CONFIG/corp_payment_fingerprints.template.json -> CONFIG/corp_payment_fingerprints.json and fill it in.")

    if not BUNDLES_DIR.exists():
        die(f"Bundles directory not found: {BUNDLES_DIR} (run from repo root or update paths)")

    cfg = load_json(CONFIG_PATH)
    corp_cards = cfg.get("corp_cards", [])
    corp_addr_needles = cfg.get("corp_billing_address_contains", [])
    policy = cfg.get("match_policy", {})

    if not corp_cards and not corp_addr_needles:
        die("Config has no corp_cards or corp_billing_address_contains; nothing to match.")

    matched = 0
    would_update = 0
    updated = 0
    skipped = 0

    matches_preview: List[str] = []

    for bundle_dir in sorted([p for p in BUNDLES_DIR.iterdir() if p.is_dir()]):
        meta_path = bundle_dir / "extracted" / "extracted_metadata.json"
        if not meta_path.exists():
            skipped += 1
            continue

        meta = load_json(meta_path)
        payment = get_payment(meta)

        match_reason = None
        match_detail: Dict[str, Any] = {}

        for cc in corp_cards:
            if strong_match_by_last4(payment, cc, policy):
                match_reason = "card_last4_match"
                match_detail = {"matched_card_label": cc.get("label",""), "matched_last4": cc.get("last4","")}
                break

        if not match_reason and corp_addr_needles and match_by_address(payment, corp_addr_needles):
            match_reason = "billing_address_match"
            match_detail = {"matched_address_tokens": corp_addr_needles[:3]}

        if not match_reason:
            continue

        matched += 1
        existing_owner = meta.get("economic_owner", "")

        decision = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "bundle_id": bundle_dir.name,
            "action": "set_economic_owner",
            "new_value": "c_corp",
            "previous_value": existing_owner,
            "reason": match_reason,
            "match_detail": match_detail,
            "payment_observed": {k: payment.get(k,"") for k in ["card_last4","card_brand","billing_zip"]},
        }

        can_update = should_overwrite_existing_owner(existing_owner)
        if can_update:
            would_update += 1

        matches_preview.append(
            f"{bundle_dir.name} reason={match_reason} last4={payment.get('card_last4','')} prev_owner={existing_owner or '∅'} update={'YES' if can_update else 'NO'}"
        )

        if args.dry_run:
            continue

        # Write decision record always (append-only) when not dry-run
        write_decision(bundle_dir, decision)

        if can_update:
            meta["economic_owner"] = "c_corp"
            if "payer" not in meta or norm(meta.get("payer","")) in ("", "tbd", "unknown"):
                meta["payer"] = "corporate"
            meta_path.write_text(json.dumps(meta, indent=2) + "\n")
            updated += 1

    if matches_preview:
        print("Matches:")
        for line in matches_preview:
            print(" - " + line)

    print("✅ Autofill complete" + (" (dry-run)" if args.dry_run else ""))
    print(f"- bundles matched: {matched}")
    print(f"- bundles that would update economic_owner: {would_update}")
    if not args.dry_run:
        print(f"- bundles updated (economic_owner set): {updated}")
    print(f"- bundles skipped (missing metadata): {skipped}")
    if args.dry_run:
        print("Note: dry-run mode wrote nothing.")
    else:
        print("Note: decision records written for every match under /decisions/.")

if __name__ == "__main__":
    main()
