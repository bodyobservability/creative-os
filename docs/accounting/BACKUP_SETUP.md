# Backup Setup (Google Drive via rclone)

This repo is designed to commit **logic** (specs/scripts/tests) but keep **evidence** (emails/receipts/bundles/exports) local.

## Recommended: rclone + Google Drive
1. Install rclone
2. `rclone config` -> create remote named `gdrive`
3. (Optional) create encrypted remote `gdrive_crypt` (recommended)

## Make targets
- `make backup-dry` : preview sync
- `make backup`     : sync local accounting data to Drive
- `make backup-zip` : create a snapshot zip and upload to Drive

## Local data root
Default local data root (ignored by git):
- `accounting/data/`
