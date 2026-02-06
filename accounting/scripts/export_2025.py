#!/usr/bin/env python3
"""Creative-OS Accounting: One-command export generator (2025)

Generates:
- accounting/data/2025/exports/schedule_c_expenses_2025.csv
- accounting/data/2025/exports/corp_reimbursable_expenses_2025.csv
- accounting/data/2025/exports/sole_prop_assets_retained_2025.csv
- accounting/data/2025/exports/sole_prop_assets_for_sale_2026.csv
- accounting/data/2025/exports/corp_asset_intake_2026.csv (draft intake list; used when corp acquires assets)

Assumptions:
- Bundle layout per specs:
  accounting/data/2025/bundles/<bundle_id>/extracted/extracted_metadata.json

Key classification axes (must exist in extracted_metadata.json):
- economic_owner: personal | sole_proprietor | c_corp
- treatment: expense | asset
Optional:
- intended_disposition: retain | sell_to_c_corp | reimburse | tbd
- proposed_fmv_2026, serial, location

This script:
- never mutates evidence
- fails loudly on missing required fields
- writes boring CSVs that map cleanly to filing / handoff tasks
"""

import csv
import json
import pathlib
import sys
from typing import Any, Dict, List

YEAR = "2025"
BASE = pathlib.Path("accounting/data/2025/bundles")  # run from repo root or update
EXPORT_DIR = pathlib.Path("accounting/data/2025/exports")

REQ = [
    "economic_owner",
    "treatment",
    "category",
    "intent_at_purchase",
    "total_amount",
    "date",
]

VALID_ECON_OWNERS = {"personal", "sole_proprietor", "sole_prop", "c_corp", "corp"}
VALID_TREATMENT = {"expense", "asset"}

def die(msg: str) -> None:
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(1)

def load_json(p: pathlib.Path) -> Dict[str, Any]:
    try:
        return json.loads(p.read_text())
    except Exception as e:
        die(f"Failed to read JSON {p}: {e}")
    raise RuntimeError

def norm_owner(v: Any) -> str:
    s = str(v).strip().lower()
    if s == "sole_prop":
        return "sole_proprietor"
    if s == "corp":
        return "c_corp"
    return s

def norm_boolish(v: Any) -> str:
    if v is True or str(v).lower() in ("true", "yes", "y"):
        return "true"
    if str(v).lower() == "ambiguous":
        return "ambiguous"
    return "false"

def ensure_required(bundle_id: str, d: Dict[str, Any]) -> None:
    for k in REQ:
        if k not in d:
            die(f"{bundle_id} missing required field '{k}'")
    if not isinstance(d["intent_at_purchase"], list) or not d["intent_at_purchase"]:
        die(f"{bundle_id} intent_at_purchase must be a non-empty list")
    try:
        float(d["total_amount"])
    except Exception:
        die(f"{bundle_id} total_amount must be numeric")
    owner = norm_owner(d["economic_owner"])
    if owner not in {"personal","sole_proprietor","c_corp"}:
        die(f"{bundle_id} economic_owner invalid: {d['economic_owner']}")
    tr = str(d["treatment"]).strip().lower()
    if tr not in VALID_TREATMENT:
        die(f"{bundle_id} treatment must be 'expense' or 'asset' (got {d['treatment']})")

def amount(x: Any) -> float:
    return round(float(x), 2)

def write_csv(path: str, rows: List[Dict[str, Any]], fieldnames: List[str]) -> None:
    out_path = pathlib.Path(path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fieldnames})

def main() -> None:
    if not BASE.exists():
        die(f"Bundles directory not found: {BASE} (run from repo root or update BASE)")

    schedule_c_rows: List[Dict[str, Any]] = []
    corp_reimb_rows: List[Dict[str, Any]] = []
    sole_assets_keep: List[Dict[str, Any]] = []
    sole_assets_sale: List[Dict[str, Any]] = []
    corp_asset_intake_2026: List[Dict[str, Any]] = []

    for bundle_dir in sorted([p for p in BASE.iterdir() if p.is_dir()]):
        bundle_id = bundle_dir.name
        meta_path = bundle_dir / "extracted" / "extracted_metadata.json"
        if not meta_path.exists():
            die(f"Missing extracted_metadata.json for bundle {bundle_id}: {meta_path}")

        d = load_json(meta_path)
        ensure_required(bundle_id, d)

        owner = norm_owner(d["economic_owner"])
        tr = str(d["treatment"]).strip().lower()
        cat = d["category"]
        dt = d["date"]
        amt = amount(d["total_amount"])

        intended = str(d.get("intended_disposition", "tbd")).strip().lower()
        vendor = d.get("vendor", "")
        desc = d.get("description", "")

        evidence_path = str(bundle_dir)

        # --- Schedule C expenses (personal return) ---
        # Include ONLY sole proprietor + expense
        if owner == "sole_proprietor" and tr == "expense":
            schedule_c_rows.append({
                "date": dt,
                "vendor": vendor,
                "amount": amt,
                "category": cat,
                "description": desc,
                "evidence_path": evidence_path,
            })

        # --- Corp reimbursable expenses (paid personally, owned economically by corp) ---
        # Not deductible personally.
        if owner == "c_corp" and tr == "expense" and intended in ("reimburse", "reimbursable", "tbd"):
            corp_reimb_rows.append({
                "date": dt,
                "vendor": vendor,
                "amount": amt,
                "category": cat,
                "description": desc,
                "evidence_path": evidence_path,
                "reimbursement_status": d.get("reimbursement_status", "tbd"),
            })

        # --- Sole-prop assets retained ---
        if owner == "sole_proprietor" and tr == "asset" and intended in ("retain", "keep", "tbd"):
            sole_assets_keep.append({
                "asset_id": bundle_id,
                "description": desc,
                "purchase_date": dt,
                "original_cost": amt,
                "category": cat,
                "evidence_path": evidence_path,
                "serial": d.get("serial", ""),
                "location": d.get("location", ""),
            })

        # --- Sole-prop assets intended for sale to corp in 2026 ---
        if owner == "sole_proprietor" and tr == "asset" and intended in ("sell_to_c_corp", "sell", "transfer_to_c_corp"):
            adj_basis = d.get("adjusted_basis_2025", "")  # leave blank unless you compute/decide
            sole_assets_sale.append({
                "asset_id": bundle_id,
                "description": desc,
                "purchase_date": dt,
                "original_cost": amt,
                "adjusted_basis_2025": adj_basis,
                "proposed_fmv_2026": d.get("proposed_fmv_2026", ""),
                "category": cat,
                "evidence_path": evidence_path,
                "serial": d.get("serial", ""),
                "location": d.get("location", ""),
            })

            # Draft corp intake row (corp side) — can be copied into 2026 corp books
            corp_asset_intake_2026.append({
                "corp_asset_id": f"corp-{bundle_id}",
                "source_asset_id": bundle_id,
                "acquisition_type": "purchase_from_founder",
                "acquisition_date": d.get("proposed_sale_date_2026", ""),
                "vendor_or_source": "founder",
                "description": desc,
                "purchase_price_2026": d.get("proposed_fmv_2026", ""),
                "original_purchase_date": dt,
                "category": cat,
                "serial": d.get("serial", ""),
                "location": d.get("location", ""),
                "evidence_path": evidence_path,
            })

        # NOTE: c_corp assets purchased directly in 2025 are intentionally excluded from personal exports.
        # If you want a corp-side 2025 asset register export, generate it from corp accounting, not this repo.

    # Write outputs (even if empty, write headers to be predictable)
    write_csv(str(EXPORT_DIR / f"schedule_c_expenses_{YEAR}.csv"), schedule_c_rows,
              ["date","vendor","amount","category","description","evidence_path"])

    write_csv(str(EXPORT_DIR / f"corp_reimbursable_expenses_{YEAR}.csv"), corp_reimb_rows,
              ["date","vendor","amount","category","description","evidence_path","reimbursement_status"])

    write_csv(str(EXPORT_DIR / f"sole_prop_assets_retained_{YEAR}.csv"), sole_assets_keep,
              ["asset_id","description","purchase_date","original_cost","category","evidence_path","serial","location"])

    write_csv(str(EXPORT_DIR / "sole_prop_assets_for_sale_2026.csv"), sole_assets_sale,
              ["asset_id","description","purchase_date","original_cost","adjusted_basis_2025","proposed_fmv_2026","category","evidence_path","serial","location"])

    write_csv(str(EXPORT_DIR / "corp_asset_intake_2026.csv"), corp_asset_intake_2026,
              ["corp_asset_id","source_asset_id","acquisition_type","acquisition_date","vendor_or_source","description","purchase_price_2026","original_purchase_date","category","serial","location","evidence_path"])

    print("✅ Exports generated:")
    print(f"- accounting/data/2025/exports/schedule_c_expenses_{YEAR}.csv ({len(schedule_c_rows)} rows)")
    print(f"- accounting/data/2025/exports/corp_reimbursable_expenses_{YEAR}.csv ({len(corp_reimb_rows)} rows)")
    print(f"- accounting/data/2025/exports/sole_prop_assets_retained_{YEAR}.csv ({len(sole_assets_keep)} rows)")
    print(f"- accounting/data/2025/exports/sole_prop_assets_for_sale_2026.csv ({len(sole_assets_sale)} rows)")
    print(f"- accounting/data/2025/exports/corp_asset_intake_2026.csv ({len(corp_asset_intake_2026)} rows)")

if __name__ == "__main__":
    main()
