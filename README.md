# HVLIEN Audio System v1.6

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

## Repository Structure (v1.6)

- `specs/` — system, controller, and intelligence specifications
- `specs/automation/` — automation schemas, substitutions, and recommendations
- `controllers/` — macro taxonomy, MPK Mini + APC40 layouts
- `ableton/`
  - `performance-sets/` — bass performance instruments (**placeholder until export**)
  - `racks/` — bass racks (**placeholder until export**)
  - `finishing-bays/` — commit + polish sets (placeholders until export)
- `ai/workloads/` — offline AI analysis + mapping specs
- `ai/pipelines/` — ingestion and bundle handling specs
- `library/` — long-lived sound artifacts (Serum base patch)
- `tools/` — checksum and integrity tooling
- `tools/automation/` — automation bundle compiler + CLI tooling
- `checksums/` — sha256 manifests per subsystem
- `notes/` — operational rules, failure modes, rituals
- `MANIFEST_AUTOMATION_BUNDLE_v3.md` — bundle contents + checks (historical)

---

## Status

**Specs:** COMPLETE (including automation bundle v4–v8.7)  
**Controller architecture:** SPECIFIED  
**AI workloads:** SPECIFIED (offline, advisory)  
**Automation tooling:** INCLUDED (Swift CLI, v4–v8.7 features applied)  
**Ableton/Serum exports:** PENDING (tracked below)

### Automation features (v4–v8.7)
- v4: regions, anchors, plan/apply automation
- v5: voice handshake + macro OCR verification
- v6: rack manifest install + verify
- v7: sonic probe/sweep calibration
- v8: station certify + reporting

### Automation Quickstart (repo already wired)
```bash
# Build CLI
cd tools/automation/swift-cli && swift build -c release

# Sanity check
.build/release/hvlien doctor --modal-test detect --allow-ocr-fallback
```

### Mac bootstrap (prereqs + UI)
- Install Xcode (Command Line Tools included) and accept license.
- Install Homebrew + OpenCV: `brew install opencv`.
- Install Ableton Live 12.3 + Serum 2 AU (if used).
- Enable IAC Driver (Audio MIDI Setup) and connect controllers (MPK Mini, APC40).
- Grant Screen Recording + Accessibility permissions to the terminal/Xcode running `hvlien`.
- Ableton UI: show Browser + Device View (Cmd+Opt+L), reveal track headers, keep theme/scale stable.
- OpenCV anchors (optional): `tools/automation/swift-cli/docs/OPENCV_BUILD.md`.

### Key docs
- Voice runtime docs + artifacts: `docs/voice_runtime/`
- OpenCV build + anchors: `tools/automation/swift-cli/docs/OPENCV_BUILD.md`
- Automation bundle manifests: `MANIFEST_AUTOMATION_BUNDLE_v2.md`, `MANIFEST_AUTOMATION_BUNDLE_v3.md`
- v4 consolidation status (historical): `V4_CONSOLIDATED_STATUS.md`
- Versioning + artifact rules: `notes/VERSIONING_RULES.md`
- Ableton build runbook: `notes/AGENTIC_ABLETON_BUILD.md`

### TODO (Required for artifact completeness)
- [ ] Export real Ableton bass performance set  
  - Replace `ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als`
- [ ] Export real Ableton finishing bays (replace placeholders)
- [ ] Export real Ableton bass racks (`.adg`) into `ableton/racks/BASS_RACKS_v1.0/`
- [ ] Commit Serum base patch (single permanent patch; macro-only)
  - Add to `library/serum/` (create folder) as `HVLIEN_SERUM_BASE_v1.0.fxp` (or `.fst`)
- [ ] Capture and commit regions profiles + overlays for standard displays (2560×1440, 5K More Space)
- [ ] Build anchor packs and validate them against live UI (if OpenCV enabled)
- [ ] Run rack install + verify and commit receipts
- [ ] Run voice template build/verify and commit receipts
- [ ] Generate sonic baselines (calibrate/sweep/tune) and commit baselines + receipts
- [ ] Run station certify and commit the run report
- [ ] Regenerate checksums after audio artifacts are added

v1.6 tooling that helps create the above:
- Regions + anchors: `calibrate-regions`, `capture-anchor`, `validate-anchors`
- Voice receipts: `voice verify`
- Rack receipts: `rack install`, `rack verify`
- Sonic baselines: `sonic calibrate`, `sonic sweep`, `sonic tune`
- Station report: `station certify`

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
- v1.5 — Automation bundle v3 specs + tooling integrated
- v1.6 — Automation tooling v4–v8.7 (CLI, anchors/regions, voice/rack/sonic specs)

---

## Non-Goals

- No real-time AI control
- No generative music
- No DAW replacement
- No erosion of Voloco capture velocity

---

This system exists to protect what already works.
