# Readiness

Accounting is ready when the repo launcher shows all greens for:

## Ingestion readiness
- Gmail Takeout (.mbox) present
- Intake extracted (.eml / attachments present)
- Bundles created under `accounting/data/2025/bundles/`

## Classification readiness
- `CONFIG/corp_payment_fingerprints.json` present (local-only)
- `make ci` passes (economic_owner complete)

## Guided close-out
Run the repo launcher and press Space:
- `make launcher` → select Accounting → Space through next steps
