# HVLIEN Audio System v1.4

*A locked vocal + bass instrument with offline AI-assisted identity stabilization.*

This repository defines **Hvlien’s production system as an instrument**, not a DAW template.
It is designed to preserve emotional capture velocity while scaling sound design, bass
performance, and long-term identity consistency.

---

## System Overview

### Capture Layer (Authoritative)
- iOS **Voloco** on iPhone or iPad
- Emotional truth is captured first
- Wet + dry exports are preserved
- iOS is **capture-only**, never overloaded

### Performance Layer
- **MPK Mini** — pitch, harmony, bass intent
- **APC40** — macros, energy, gesture
- Controllers are locked instruments, not generic MIDI

### Sound Engine Layer
- **Serum** (single permanent patch; macro-only)
- Ableton-native instruments and racks
- No plugin sprawl

### Transformation Layer
- Ableton Live resampling-first workflows
- Early commitment, flattening, re-ingestion
- Performance defines sound, not tweaking

### Intelligence Layer (Offline Only)
- AI analyzes *past Hvlien tracks* to learn bass and timbral identity
- AI outputs **recommendations**, never live control:
  - sound families
  - macro ranges
  - controller mappings
- Human-gated, offline, advisory only

### Integrity Layer
- Versioned specs
- Checksum manifests
- Acceptance tests
- Drift prevention

---

## Repository Structure (v1.4)

- `specs/` — system, controller, and intelligence specifications
- `controllers/` — macro taxonomy, MPK Mini + APC40 layouts
- `ableton/`
  - `performance-sets/` — bass performance instruments (**placeholder until export**)
  - `racks/` — bass racks (**placeholder until export**)
  - `finishing-bays/` — commit + polish sets (placeholders until export)
- `ai/workloads/` — offline AI analysis + mapping specs
- `ai/pipelines/` — ingestion and bundle handling specs
- `library/` — long-lived sound artifacts (Serum base patch)
- `tools/` — checksum and integrity tooling
- `checksums/` — sha256 manifests per subsystem
- `notes/` — operational rules, failure modes, rituals

---

## Status

**Specs:** COMPLETE  
**Controller architecture:** SPECIFIED  
**AI workloads:** SPECIFIED (offline, advisory)  
**Ableton/Serum exports:** PENDING (tracked below)

### TODO (Required for artifact completeness)
- [ ] Export real Ableton bass performance set  
  - Replace `ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als`
- [ ] Export real Ableton finishing bays (replace placeholders)
- [ ] Export real Ableton bass racks (`.adg`) into `ableton/racks/BASS_RACKS_v1.0/`
- [ ] Commit Serum base patch (single permanent patch; macro-only)
  - Add to `library/serum/` (create folder) as `HVLIEN_SERUM_BASE_v1.0.fxp` (or `.fst`)
- [ ] Regenerate checksums after audio artifacts are added

Until the above are complete, this repo should be considered **SPEC-COMPLETE, ARTIFACT-PENDING**.

---

## Contributing

See `CONTRIBUTING.md` for commit message standards and contribution guidelines.

---

## Version Lineage

- v1.0 — Core vocal + finishing bay system
- v1.1 — Intelligence Plane (analysis + recommendation)
- v1.2 — Controller-aware AI workloads
- v1.3 — MPK Mini + APC40 instrument layer
- v1.4 — README truth + packaging alignment (no spec changes)

---

## Non-Goals

- No real-time AI control
- No generative music
- No DAW replacement
- No erosion of Voloco capture velocity

---

This system exists to protect what already works.
