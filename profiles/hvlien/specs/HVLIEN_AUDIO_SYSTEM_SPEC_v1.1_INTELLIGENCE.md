# HVLIEN AUDIO SYSTEM
## SPEC v1.1 — INTELLIGENCE PLANE EXTENSION

> Additive extension to v1.0. This spec defines how AI compute integrates without affecting the artist’s real-time creative loop.

---

## 0. PURPOSE

Define the **Intelligence Plane** (Linux AI workstation[s]) alongside:
- iPhone (Voloco) — Ignition Plane
- MacBook Pro (Ableton Live Suite) — Execution Plane
- iPad (optional) — Tactile Control Plane

Goals:
- increase engineering leverage and longitudinal insight
- support library backfill + ongoing production loop
- never introduce latency, cognitive drag, or upstream pressure on the artist

---

## 1. NON-NEGOTIABLE PRINCIPLE

**AI never participates in the real-time creative loop.**

- AI output is offline/nearline and advisory
- AI artifacts are human-gated
- If AI is offline, the system remains fully functional

---

## 2. DEVICE ROLES

### 2.1 iPhone (Voloco) — Ignition Plane (unchanged)
- primary vocal creation instrument
- zero dependency on network/AI
- must function standalone/offline

### 2.2 MacBook Pro — Execution Plane (extended)
- Ableton Live Suite (Finishing Bays, optional Wub Field later)
- routing/monitoring/controller mapping
- **ingestion point** for AI artifacts (manual approval only)

### 2.3 iPad (optional) — Tactile Control Plane (unchanged)
- touch macro control / visualization
- not authoritative; no required state

### 2.4 Linux AI workstation(s) — Intelligence Plane (new)
- batch + nearline analysis and suggestion generation
- never time-coupled to live audio

---

## 3. DATA FLOW CONSTRAINTS

### 3.1 Directionality (no live feedback loop)

```
[iPhone/Voloco] -> (WAV export) -> [Mac] -> [Linux AI] -> (artifact bundle) -> [Mac (human-approved import)]
```

### 3.2 Timing constraints
- Ignition + Execution planes are latency-critical
- Intelligence plane is latency-irrelevant
- AI artifacts must never be required during creation

---

## 4. INPUT SOURCES (CANONICAL)

### 4.1 Primary canonical input (required)
- **Voloco WAV exports** (lossless preferred)

### 4.2 Allowed additional inputs (optional)
- Existing WAV masters (previous releases)
- Lossy references (MP3/M4A) as reference-only, flagged in reports
- AI-separated stems generated offline on Linux (optional; manual trigger; versioned)

### 4.3 Prohibited inputs (as requirements)
- Any workflow that requires the artist to export extra files during creation (e.g., mandatory stems)

---

## 5. LIBRARY INGEST MODES

### 5.1 Backfill mode (one-time)
- analyze the existing catalog of Voloco WAV exports + existing masters
- build a similarity index + baseline statistics

### 5.2 Incremental mode (continuous)
- analyze new Voloco WAV exports as they appear
- update index and emit per-track bundles

Both modes:
- output versioned artifacts
- do not overwrite
- do not auto-apply to Ableton

---

## 6. INTELLIGENCE PLANE RESPONSIBILITIES

Allowed:
- track fingerprinting (loudness, dynamics proxy, spectral balance)
- phrase/section segmentation (by audio, not grid)
- similarity & retrieval (nearest neighbors in her own catalog)
- finishing bay recommendation (Primary/Dark/Light) with confidence
- modulation curve suggestions (control signals, not composition)
- controller mapping recommendations (offline only; human-applied)

Forbidden:
- injecting audio into live paths
- modifying Ableton projects directly
- driving controller motion in real time
- prompting the artist or intervening mid-session
- auto-applying results to Ableton

---

## 7. AI ARTIFACT BUNDLES (VERSIONED)

### 7.1 Bundle structure (Linux -> Mac)

```
/HVLIEN/AI/inbox/<TrackID>/
  manifest.json
  report.json
  segments.json
  neighbors.json
  label.json
  curves.json
```

### 7.2 Manifest requirements
- track_id
- source_path
- source_sha256
- created_at
- model_versions
- recommended_bay + confidence
- warnings (low-end heavy, sibilance high, etc.)

### 7.3 Human gating
- engineer chooses to accept/ignore suggestions
- no auto-apply permitted

---

## 8. RELIABILITY

- AI offline: no impact on creation/finishing bays
- AI wrong: discard bundle; no corrective action required
- no cloud dependency required

---

## 9. SUCCESS CRITERIA

- artist never thinks about AI
- creative velocity unchanged
- engineer gains foresight and consistency
- system quality improves over time without added drag

---


## 7.4 Controller mapping bundles (catalog-level)
Controller mapping bundles are generated against the whole catalog (or a defined subset) and are versioned separately from per-track bundles.

Suggested structure:

```
/HVLIEN/AI/inbox/controller_mapping/<bundle_id>/
  mapping_bundle.json
  families.json
  curves.json
  features_summary.json
  README.md
```

These bundles are advisory and must be implemented manually in Ableton/Serum, then versioned under `controllers/` and `ableton/`.

Reference workload: `ai/workloads/AI_WORKLOAD_SPEC_v1.2_CONTROLLER_MAPPING.md`
# END SPEC v1.1
