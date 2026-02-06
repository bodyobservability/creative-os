# Lifecycle

Accounting proceeds per-epoch, then becomes dormant.

1. Ingest (manual exports, no inbox mutation)
2. Bundle (hash + dedupe, create ReceiptBundles)
3. Classify (economic_owner + treatment + intent; apply corp-card autofill)
4. Export (Schedule C CSV, corp reimbursement CSV, corp asset intake CSV)
5. Backup (Drive sync via rclone)
6. Seal (optional local marker)

Corrections happen by **supersession** in later epochs, never by rewriting past epochs.
