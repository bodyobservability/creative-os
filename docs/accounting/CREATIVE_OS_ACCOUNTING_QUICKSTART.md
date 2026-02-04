# Creative-OS Accounting QuickStart (v1.1+)

This QuickStart gets you from **multiple inboxes → evidence → classification → exports → TaxAct** with minimal cognitive load.

## Key Guarantees
- No API keys required
- No OAuth apps required
- No inbox mutation required
- Evidence is immutable once captured

---

## 0) Choose your scope
- Tax year window: **2025-01-01 → 2025-12-31**
- Accounts: **2–3 Gmail** + **2 iCloud**

Recommendation: pick **one primary Gmail** as the consolidation surface for iCloud forwarding.
Still run Takeout for every Gmail that may contain receipts.

---

## 1) Add the accounting domain to your repo
If you have a sealed epoch archive, keep it local-only under:
```
accounting/epochs/2025/ARCHIVE/
  creative-os.accounting.epoch-2025.complete.zip
```
Treat it as read-only and do not commit it.

---

## 2) Prepare labels and filters in each Gmail (repeat per Gmail)
Create labels:
- `receipts-2025`
- `icloud-import-2025` (only needed on the primary Gmail)

Add a broad receipt filter (over-capture is OK):
```
has:attachment after:2025/01/01 before:2026/01/01
```
Action: apply label `receipts-2025` (no deletes).

Optional vendor boosts:
```
(after:2025/01/01 before:2026/01/01) (receipt OR invoice OR order OR "tax invoice")
```

---

## 3) Forward iCloud → primary Gmail (temporary)
On each iCloud account:
- Enable forwarding to your **primary Gmail**
- Keep copy in iCloud (recommended)

In primary Gmail, filter iCloud mail:
```
from:(*@icloud.com)
```
Action: label `icloud-import-2025`.

**Important note:** iCloud forwarding is typically forward-from-now; for historical mail, use Apple Mail rules to forward/drag-send relevant folders, or export iCloud mail separately via Mail.app.

Once you’ve captured the window, turn forwarding OFF.

---

## 4) Run Google Takeout (repeat per Gmail)
For each Gmail:
- Google Takeout → select **Mail only**
- Export (produces `.mbox`)

Name files clearly:
- `gmail_primary_2025.mbox`
- `gmail_secondary_2025.mbox`

---

## 5) Build your intake folder
Recommended structure:
```
accounting/2025/intake/
  gmail/<account>/...
  icloud/<account>/...   (optional if you export separately)
```

Extract from `.mbox`:
- `.eml` message files
- attachments (PDF/images)

---

## 6) Apply Bundle 01 (evidence)
Offline only:
- SHA-256 hash all attachments
- Deduplicate identical hashes
- Preserve provenance: attachment ↔ source email(s)

Create bundles:
```
accounting/2025/bundles/<bundle_id>/...
```

---


## 6.5) Optional: Autofill C-corp purchases by card fingerprint (high leverage)
If you know which card last4 / billing info belongs to the C-corp, you can auto-mark those bundles:

1) Copy template:
- `CONFIG/corp_payment_fingerprints.template.json` → `CONFIG/corp_payment_fingerprints.json`
2) Fill in your corp card **last4** and billing tokens (never full card numbers)
3) Run:
```bash
python3 accounting/scripts/autofill_economic_owner.py
```

This will:
- write a decision record per match under `bundles/<id>/decisions/`
- set `economic_owner=c_corp` only when missing/tbd (conservative overwrite)
- set `payer=corporate` if missing

## 7) Apply Bundle 02 (classification)
Use `accounting/scripts/VENDOR_AUTO_CLASSIFIER_TABLE.md` to auto-fill ~95%:
- software subscriptions → auto-green
- electronics suppliers → default expense, ambiguous when high-cost
- marketplaces (Amazon/eBay) → item parse + review
- Apple → services auto-green, hardware threshold

For every bundle, finalize:
- economic_owner: personal | sole_proprietor | c_corp
- treatment: expense | asset   ← NEW (separates corp asset purchase vs corp expense)
- payer: personal | sole_proprietor | corporate
- intent_at_purchase[]
- category
- is_asset_candidate: false | ambiguous | true
- intended_disposition: retain | sell_to_c_corp | reimburse | tbd

Mandatory review:
- any single item > $1,000
- any marketplace purchase
- any asset_candidate != false

---

## 8) Generate exports (one command)
Run from repo root:
```bash
python3 accounting/scripts/export_2025.py
```

Outputs:
- `schedule_c_expenses_2025.csv`
- `corp_reimbursable_expenses_2025.csv`
- `sole_prop_assets_retained_2025.csv`
- `sole_prop_assets_for_sale_2026.csv`
- `corp_asset_intake_2026.csv`

---

## 9) File with TaxAct (fast path)
- Use CSV totals as authoritative
- Enter totals per category
- Keep evidence archive available (but do not upload unless asked)

---

## 10) Completeness checks (do before filing)
- Spot-check top vendors: OpenAI, Anthropic, OpenRouter, Runpod, JetBrains, Adobe, Digi-Key/Mouser, B&H, Amazon
- Compare Gmail label counts vs exported message counts (rough sanity)
- Ensure portal-only invoices are included (if any)

---

## 11) Close the year
- Disable iCloud forwarding
- Tag repo: `accounting-epoch-2025-v1.1+`
- Do not rewrite 2025; supersede in 2026 if needed.


## Convenience: Make targets
From repo root:
```bash
make dry-run
make autofill
make ci
make exports
# or one-shot:
make all
```


## Repo hygiene (recommended)
- Add `docs/accounting/GITIGNORE_SNIPPET_ACCOUNTING.txt` to your repo `.gitignore`.
- Keep evidence under `accounting/data/` (local-only).

## Convenience targets
```bash
make init-config
make dry-run
make autofill
make ci
make status
make exports
make all
```

## Backups (optional)
Requires `rclone` configured with a remote named `gdrive` (or `gdrive_crypt`).
```bash
make backup-dry
make backup
make backup-zip
```


## Accounting TUI (guided workflow)
Install Textual (recommended in a venv):
```bash
pip install textual
```
Run:
```bash
python -m creative_os.shell accounting
```
Use `Space` to run the recommended next action, `m` to toggle SAFE/GUIDED/ALL.
In ALL mode, dangerous actions require `y` to confirm (`n` cancels).


## Optional: Seal the year (after filing)
In the TUI, switch to ALL mode and run `seal-epoch` (requires y-confirm). This writes a local marker under `accounting/epochs/2025/SEALED.marker`.
