# v1.7.10 First-Run Wizard — Asset Export Phase

The first-run wizard inside `wub ui` now guides initial artifact exports after the basic setup steps.

## Flow
After Build → Sweep → Index build, the wizard checks `checksums/index/artifact_index.v1.json` for missing or placeholder artifacts.

If artifacts are pending, it offers:
1. Export ALL (recommended)
2. Export step-by-step (guided)
3. Print commands only
4. Skip for now

## Safety
- Every destructive/clicky action is explicitly confirmed.
- No Ableton set switching or UI manipulation happens automatically.
- If anchors pack is unset, the wizard offers a **Validate Anchors** pre-step.

## State persistence
`notes/LOCAL_CONFIG.json` includes:
- `firstRunCompleted`
- `artifactExportsCompleted`
