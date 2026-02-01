# Wizard receipt (v1.7.12)

The first-run wizard writes a full step-log receipt to:
- `runs/<wizard_run_id>/wizard_receipt.v1.json`

The receipt records:
- each prompted step
- user decision (yes/no/skip)
- exit codes (when executed)
- anchors pack used

This supports auditability and remote debugging.
