# v1.7.9 First-Run Wizard (Operator Shell)

On first launch of `hvlien ui`, a one-time wizard appears if `notes/LOCAL_CONFIG.json` indicates first run.

The wizard offers (with confirmation prompts):
1) Build CLI (`swift build -c release`)
2) Doctor (`hvlien doctor --modal-test detect --allow-ocr-fallback`)
3) Index build (`hvlien index build`)

After completion it sets:
- `notes/LOCAL_CONFIG.json` → `firstRunCompleted: true`

You can reset the wizard by deleting:
- `notes/LOCAL_CONFIG.json`
or setting `firstRunCompleted` to false.
