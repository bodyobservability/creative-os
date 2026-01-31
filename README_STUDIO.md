# HVLIEN Audio System — Studio Guide (v1.8.4)

This guide is for **studio operation**: fast, safe, low wrist strain.

## Start here

```bash
make studio
```

That builds the CLI (if needed) and opens the **Operator Shell** (`hvlien ui`).
On first launch, a one-time wizard offers to run build/doctor/index steps.

## Operator Shell essentials

### Modes
- **Studio Mode**: `s` (safe-only; hides risky actions)
- **Voice Mode**: `v` (numbered actions + “Say ‘press N’” prompts; number keys 1–9 select)

### One-key flow
- **Space**: run recommended next action
- **p**: preview drift remediation plan
- **R**: refresh state

### Open evidence
- `r`: open last receipt
- `o`: open last report
- `f`: open last run folder
- `x`: open last failures folder

## Studio loop (recommended)

Inside the Operator Shell:
1. **Doctor** → confirm permissions & modal guard
2. **Validate anchors** (recommended) → ensures stable clicking/save dialogs
3. **Assets → Export ALL** → replaces placeholders with real Ableton/Serum artifacts
4. **Index build** → **Drift check** → **Drift fix (guarded)** if needed
5. **Station certify** when you want a full proof-of-health receipt

## Non-goals
- No live AI control
- No generative music
- No DAW replacement

This system exists to protect capture velocity and keep the instrument stable.
