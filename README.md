# HVLIEN Audio System v1.7.1

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

## Repository Structure

- `specs/` — system, controller, and intelligence specifications
- `specs/automation/` — automation schemas, substitutions, and recommendations
- `specs/assets/` — export pipeline specs + receipts
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
- `docs/assets/` — asset export runbooks and reference docs

---

## Status

**Specs:** COMPLETE (including automation tooling + specs)  
**Controller architecture:** SPECIFIED  
**AI workloads:** SPECIFIED (offline, advisory)  
**Automation tooling:** INCLUDED (Swift CLI)  
**Ableton/Serum exports:** PENDING (tracked below)

### Automation features
- regions, anchors, plan/apply automation
- voice handshake + macro OCR verification
- rack manifest install + verify
- sonic probe/sweep calibration
- station certify + reporting
- voice runtime layer + VRL validation + MIDI utilities

### Automation Quickstart (First-Time Setup on macOS)

This section gets you from a fresh clone to a fully operational automation + voice + export pipeline in ~20 minutes.

Goal: build the CLI, verify UI automation safety, and be ready to export real Ableton assets without mouse-heavy setup.

#### 0) Prerequisites (one-time)

macOS
- macOS Sonoma or later (Tahoe recommended for Voice Control improvements)

Install tooling
```bash
# Xcode CLI tools
xcode-select --install

# Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# OpenCV (optional but recommended for anchor robustness)
brew install opencv
```

Install apps
- Ableton Live 12.3
- Serum 2 AU (if used)
- Keyboard Maestro (recommended for voice → command binding)

#### 1) Clone and build the CLI
```bash
git clone <repo-url>
cd hvlien-audio-system-main

cd tools/automation/swift-cli
swift build -c release

.build/release/hvlien --help
```

#### 2) Grant macOS permissions (required)

Open System Settings → Privacy & Security and grant:
- Screen Recording
- Accessibility

to:
- Terminal (or iTerm)
- Xcode (if running from Xcode)
- Keyboard Maestro (if using voice triggers)

⚠️ Automation will not work without these.

#### 3) Basic UI sanity check (safe)

This ensures the automation stack can see the screen and won’t brick anything.
```bash
.build/release/hvlien doctor --modal-test detect --allow-ocr-fallback
```

Expected:
- Modal detection passes
- No crashes
- No clicks performed

#### 4) Select display profile + calibrate regions (required once per display)
```bash
.build/release/hvlien regions-select \
  --display 2560x1440 \
  --config-dir tools/automation/swift-cli/config

.build/release/hvlien calibrate-regions \
  --regions-config tools/automation/swift-cli/config/regions.v1.json
```

This step is critical for OCR accuracy.

#### 5) Capture and validate anchors (recommended)

Anchors improve robustness (especially for Serum and save dialogs).
```bash
.build/release/hvlien capture-anchor \
  --regions-config tools/automation/swift-cli/config/regions.v1.json \
  --region browser.search

.build/release/hvlien validate-anchors \
  --regions-config tools/automation/swift-cli/config/regions.v1.json \
  --pack /path/to/anchor_pack
```

You can skip anchors initially, but they are strongly recommended for v1.7.1 exports.

#### 6) Verify voice runtime layer (optional but recommended)

Enable IAC Driver (Audio MIDI Setup → MIDI Studio → IAC Driver → “Device is online”).

Then verify:
```bash
.build/release/hvlien midi list
.build/release/hvlien vrl validate \
  --mapping specs/voice_runtime/v9_3_ableton_mapping.v1.yaml
```

This confirms:
- MIDI bus visibility
- ABI macro labels
- VRL readiness

#### 7) (Optional) Bind Tahoe / Voice Control to commands

Recommended phrases:
- “export everything” → hvlien assets export-all
- “check drift” → hvlien drift check (future v1.8)
- “certify station” → hvlien station certify

Use Keyboard Maestro or Shortcuts to map phrases → shell commands.

Voice is used as an operator interface, not parameter control.

#### 8) Ready to export real assets (no mouse)

Once Ableton is open and the correct sets are loaded:
```bash
.build/release/hvlien assets export-all \
  --anchors-pack specs/automation/anchors/<pack_id> \
  --overwrite
```

This replaces all placeholder artifacts with real exports and emits receipts.

#### What you have after this
- ✅ CLI built and verified
- ✅ UI automation safe
- ✅ Voice runtime optional but working
- ✅ Asset export pipeline ready
- ✅ Repo is SPEC-COMPLETE, EXPORT-READY

#### When to stop

If you’ve completed steps 1–4, you are safe to proceed slowly.
Steps 5–8 can be done incrementally as needed.

#### Why this matters (ergonomics)

This setup:
- minimizes mouse use
- allows keyboard-only or voice-triggered workflows
- prevents repeated manual export pain
- protects wrists during long engineering sessions

### Automation CLI quick reference
```bash
# Display/profile setup
.build/release/hvlien regions-select --display 2560x1440 --config-dir tools/automation/swift-cli/config

# Regions + anchors
.build/release/hvlien calibrate-regions --regions-config tools/automation/swift-cli/config/regions.v1.json
.build/release/hvlien capture-anchor --regions-config tools/automation/swift-cli/config/regions.v1.json --region browser.search
.build/release/hvlien validate-anchors --regions-config tools/automation/swift-cli/config/regions.v1.json --pack /path/to/anchor_pack

# Plan/apply
.build/release/hvlien plan --in /path/to/specs --out /tmp/plan.json
.build/release/hvlien apply --plan /tmp/plan.json

# Racks + voice
.build/release/hvlien rack install --plan specs/voice/scripts/rack_pack_install.v1.yaml
.build/release/hvlien rack verify --plan specs/library/racks/verify_rack_pack.plan.v1.json
.build/release/hvlien voice verify --plan specs/voice/verify/verify_abi.plan.v1.json

# Voice runtime layer
.build/release/hvlien vrl validate --mapping specs/voice_runtime/v9_3_ableton_mapping.v1.yaml
.build/release/hvlien midi list

# Asset exports
.build/release/hvlien assets export-racks --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-performance-set --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-finishing-bays --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-serum-base --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-extras --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-all --anchors-pack specs/automation/anchors/<pack_id> --overwrite

# Sonic + station
.build/release/hvlien sonic calibrate
.build/release/hvlien sonic sweep
.build/release/hvlien sonic tune
.build/release/hvlien station certify
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
- Asset export runbooks: `docs/assets/`
- OpenCV build + anchors: `tools/automation/swift-cli/docs/OPENCV_BUILD.md`
- Versioning + artifact rules: `notes/VERSIONING_RULES.md`
- Ableton build runbook: `notes/AGENTIC_ABLETON_BUILD.md`

### Artifact Completeness Checklist

The repository is considered **ARTIFACT-COMPLETE** when all items below exist, are non-placeholder, and have corresponding receipts committed.

Most items can be produced by running:
```bash
.build/release/hvlien assets export-all --anchors-pack specs/automation/anchors/<pack_id> --overwrite
```

#### Automatically generated via `assets export-all`
- [ ] Export real Ableton bass performance set  
  - Replace `ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als`
- [ ] Export real Ableton finishing bays (replace placeholders)
- [ ] Export real Ableton bass racks (`.adg`) into `ableton/racks/BASS_RACKS_v1.0/`
- [ ] Commit Serum base patch (single permanent patch; macro-only)
  - Add to `library/serum/` (create folder) as `HVLIEN_SERUM_BASE_v1.0.fxp` (or `.fst`)
- [ ] Export return FX + master safety racks

#### One-time environment / validation tasks
- [ ] Capture and commit regions profiles + overlays for standard displays (2560×1440, 5K More Space)
- [ ] Build anchor packs and validate them against live UI (if OpenCV enabled)
- [ ] Run rack install + verify and commit receipts
- [ ] Run voice template build/verify and commit receipts
- [ ] Run voice runtime validation (VRL) and commit the receipt
- [ ] Generate sonic baselines (calibrate/sweep/tune) and commit baselines + receipts
- [ ] Run station certify and commit the run report
- [ ] Regenerate checksums after audio artifacts are added

Tooling that helps create the above:
- Regions + anchors: `calibrate-regions`, `capture-anchor`, `validate-anchors`
- Voice receipts: `voice verify`
- VRL receipt: `vrl validate`
- Rack receipts: `rack install`, `rack verify`
- Asset exports: `assets export-all`
- Sonic baselines: `sonic calibrate`, `sonic sweep`, `sonic tune`
- Station report: `station certify`

v1.7.1 milestone: every artifact in the repo can be generated, verified, and re-generated without UI clicking.

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
- v1.5 — Automation specs + tooling
- v1.6 — Expanded automation + sonic + certification
- v1.7 — Voice runtime layer (VRL) + MIDI utilities
- v1.7.1 — Asset export pipeline (repo completeness)

---

## Roadmap

This roadmap uses the **same repo lineage** versioning (no parallel automation-only versions).

### v1.8 — Artifact & Receipt Index + Drift Detection
- Build a unified `ArtifactIndex` + `ReceiptIndex` over:
  - v9.5 export receipts (racks/sets/bays/Serum/extras)
  - v7 sonic receipts (sweep/calibrate/sub-mono/transient)
  - v8 certify/release receipts
  - v9 VRL mapping receipts
- Add drift checks:
  - “artifact changed but not re-exported”
  - “baseline missing or stale”
- CLI targets (draft):
  - `hvlien index build`, `hvlien index status`, `hvlien drift check`

### v1.9 — Cross-Rack Intelligence (bass-focused)
- Analyze interactions between exported artifacts:
  - Sub ↔ BassLead mono/phase stability
  - Return FX low-end smearing
  - Transient collisions (kick/sub/bass)
- Output ranked recommendations and proposed patches (never auto-applied):
  - “tighten Motion high bound”
  - “reduce Width max for sub safety”

### v2.0 — Constrained Auto-Tuning Proposals
- Generate *proposed* profile patches from measured receipts under strict constraints:
  - calibrated sweeps, regression diffs, and release gates
- Output PR-friendly patch artifacts; promotion remains gated by certify/release pipeline.

### v2.1 — Set-Level Intelligence (optional, heavier)
- Scene-to-scene energy / contrast analysis on exported performance sets
- Suggested macro snapshots per scene (still discrete and bounded)

### v2.2 — Performance Guarantees (optional)
- Live-set safety certification across scenes:
  - no clipping, no silence, no runaway macros
- Emit a “tour-ready” style receipt

---

## Non-Goals

- No real-time AI control
- No generative music
- No DAW replacement
- No erosion of Voloco capture velocity

---

This system exists to protect what already works.
