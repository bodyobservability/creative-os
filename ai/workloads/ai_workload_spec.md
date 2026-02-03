# AI Workload Spec

Version: current

Primary canonical input: **Voloco WAV exports**.

## 1) Hardware roles

### Linux Blackwell workstation(s)
- batch + nearline inference (heavy workloads)
- backfill of entire catalog
- embeddings/similarity indexing
- curve generation
- optional stem separation (manual, offline only)

### MacBook Pro (M4 Max)
- Ableton Live Suite + finishing bays
- ingestion of AI bundles (manual approval)
- optional light metrics (no heavy inference during sessions)

### iPhone (Voloco)
- creation only; no AI coupling

### iPad (optional)
- tactile control/visualization only; not part of AI pipeline

---

## 2) Workload A — Track fingerprinting (required)

Input: WAV  
Outputs:
- loudness: integrated + short-term proxy
- dynamic range proxy
- spectral balance summary
- low-end energy ratio
- sibilance estimate
- silence/activity ratio
- tempo estimate (reference-only)

Artifacts:
- report.json
- curves.json (energy contour lanes)

Cadence:
- backfill: all existing WAVs
- incremental: every new export

---

## 3) Workload B — Phrase/section segmentation (recommended)

Outputs:
- phrase boundaries
- hook density hotspots
- drop candidates (energy discontinuities)
- breath/space markers

Artifacts:
- segments.json

---

## 4) Workload C — Similarity & retrieval (required)

Outputs:
- top-k nearest tracks
- novelty score

Artifacts:
- neighbors.json

---

## 5) Workload D — Finishing bay recommendation (required)

Outputs:
- label.json with Primary/Dark/Light + confidence + rationale tags

---

## 6) Workload E — Modulation curve synthesis (optional, deferred)

Outputs:
- curves.json lanes suitable for macro automation suggestions
Non-authoritative. Human-gated.

---

## 7) Optional: Stem separation (manual trigger only)

Not required for backfill or finishing bays.
Use only for remix/deep production.

---

# END
