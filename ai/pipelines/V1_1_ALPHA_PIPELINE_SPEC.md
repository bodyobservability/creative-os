# V1_1_ALPHA_PIPELINE_SPEC

Minimal runnable pipeline for:
- library backfill
- incremental new-export analysis

## 1) Inputs (Linux)
- Backfill library: `/mnt/ai/library_in/`
- New exports watch: `/mnt/ai/voloco_exports_in/`
Canonical input: WAV.

## 2) Outputs (Linux)
- Per-track bundles: `/mnt/ai/outbox/<TrackID>/`
- Global index: `/mnt/ai/index/`

## 3) Modes
### Backfill
- run Workloads A, C, D (and B if enabled) for all WAVs
- build similarity index
- emit bundles + catalog summary

### Incremental watch
- watch for new WAV
- run Workloads A–D
- update index
- emit bundle

## 4) Transfer to Mac
Use rsync/SMB/Syncthing.
Requirement: atomic bundle transfer.

---

# END
