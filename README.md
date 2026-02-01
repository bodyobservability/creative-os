# HVLIEN Audio System v1.8.4

*A locked vocal + bass instrument with offline AI-assisted identity stabilization.*

> **OPERATION NOTE**  
> This system is operated via the **Operator Shell**:
>
> ```bash
> make studio
> # or: tools/automation/swift-cli/.build/release/hvlien ui
> ```
>
> Studio workflow lives in **README_STUDIO.md**. This README is the technical source of truth (architecture/specs/integrity).


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
- artifact/receipt index + drift detection (check/plan/fix)
- operator shell wizard + ready verifier

### Automation Quickstart (First-Time Setup on macOS)

This repo is designed to be operated via the **Operator Shell** (`hvlien ui`) so you don’t have to memorize commands.

#### 0) Prerequisites (one-time)

- macOS Sonoma or later (Tahoe recommended for Voice Control improvements)
- Ableton Live 12.3 (+ Serum 2 AU if used)
- Xcode Command Line Tools:
```bash
xcode-select --install
```
- Homebrew (if needed) + optional OpenCV (for anchor robustness):
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install opencv
```

#### 1) Build the CLI

```bash
cd tools/automation/swift-cli
swift build -c release
```

#### 2) Grant macOS permissions (required)

System Settings → Privacy & Security → grant **Screen Recording** + **Accessibility** to the app you run `hvlien` from (Terminal / iTerm / Xcode).

#### 3) Launch the Operator Shell

From repo root:
```bash
make studio
```

Inside the shell:
- **Studio Mode** (`s`) hides risky actions by default
- **Voice Mode** (`v`) shows “Say ‘press 3’” prompts and allows number-only selection (1–9)
- **Space** runs the recommended next action
- Shortcuts: `r` receipt, `o` report, `f` run folder, `x` failures

#### 4) Recommended first loop

In the Operator Shell, run in order (or just press **Space** repeatedly):

1. **Doctor** (sanity check)
2. **Regions calibrate** (if needed)
3. **Validate anchors** (recommended)
4. **Assets → Export ALL** (when Ableton is open and ready)
5. **Index build** → **Drift check** (v1.8)

All steps emit receipts into `runs/<run_id>/...` and can be opened from the shell.



### Automation CLI reference
Full reference lives in `docs/automation/cli_reference.md`. For daily use, prefer the Operator Shell (`make studio`).

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
- Operator shell docs: `docs/voice_runtime/operator_shell.md`
- Operator shell auto-detect update: `docs/voice_runtime/README_v1_7_5.md`
- Operator shell stateful update: `docs/voice_runtime/README_v1_7_6.md`
- Operator shell plan preview update: `docs/voice_runtime/README_v1_7_7.md`
- Operator shell voice studio update: `docs/voice_runtime/README_v1_7_8.md`
- Operator shell wizard update: `docs/voice_runtime/README_v1_7_9.md`
- Operator shell wizard guide: `docs/voice_runtime/operator_shell_wizard.md`
- Operator shell wizard receipt: `docs/voice_runtime/operator_shell_wizard_receipt.md`
- Ready verifier docs: `docs/index/ready_verifier.md`
- Makefile ready target: `docs/index/README_make_ready.md`
- Asset export runbooks: `docs/assets/`
- Station status: `docs/station/station_status.md`
- Station gating: `docs/station/gating_v1_7_18.md`
- Index + drift docs: `docs/index/`
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
- v1.7.5 — Operator shell + anchor auto-detect
- v1.7.6 — Operator shell stateful UI (badges, one-key flow)
- v1.7.7 — Operator shell plan preview + drift UX
- v1.7.8 — Operator shell voice/studio modes
- v1.7.9 — Operator shell first-run wizard
- v1.7.10 — Wizard asset export phase
- v1.7.11 — Wizard receipt
- v1.7.12 — Wizard receipt step log + schema
- v1.7.14 — Ready verifier command + report schema
- v1.7.15 — Operator shell ready hotkey + verifier flow
- v1.8 — Artifact/receipt index + drift detection + guarded fixes

---

## Roadmap

This roadmap uses the **same repo lineage** versioning (no parallel automation-only versions).
Export-all makes artifacts deterministic; v1.8+ intelligence is ledger/graph-driven, not UI-driven.
From v1.8 onward, intelligence operates over indexed artifacts and receipts, not live DAW state.

### v1.8 — Artifact & Receipt Index + Drift Detection (implemented)
- Build a unified `ArtifactIndex` + `ReceiptIndex` over:
  - v9.5 export receipts (racks/sets/bays/Serum/extras)
  - v7 sonic receipts (sweep/calibrate/sub-mono/transient)
  - v8 certify/release receipts
  - v9 VRL mapping receipts
- DependencyGraph (sets → racks → profiles → macros → receipts)
- Add drift checks:
  - “artifact changed but not re-exported”
  - “baseline missing or stale”
- CLI targets (draft):
  - `hvlien index build`, `hvlien index status`, `hvlien drift check`
  - Example: `hvlien index build && hvlien drift check`

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

Voice-as-operator examples:
- “export everything”
- “check drift”
- “build index”
- “certify station”
- “run cross-rack analysis”

---

## Non-Goals

- No real-time AI control
- No generative music
- No DAW replacement
- No erosion of Voloco capture velocity

---

This system exists to protect what already works.
