# HVLIEN CONTROLLER LAYER - SPEC v1.0

Status: Active

## 0. Intent
Hvlien's throughput depends on a tight loop:

1) Capture emotion fast (iOS Voloco)
2) Explore bass fast (hardware controllers)
3) Commit audio fast (Ableton resample / freeze / flatten)

This spec makes the controller layer a production artifact: a stable, versioned mapping for Akai MPK Mini + Akai APC40 that turns bass sound design into a performable instrument.

Core idea:
- Hands touch controllers.
- Controllers touch macros.
- Macros touch synth/device parameters.
- Audio is committed early.

## 1. Non-negotiables
1) Macro-only control
- Controllers map to a fixed macro taxonomy (see controllers/MACRO_TAXONOMY_v1.0.md).
- Normal play does NOT directly map knobs to dozens of raw parameters.

2) Session-invariant mappings
- The same knob/fader does the same conceptual thing in every bass session.
- Changes require a version bump and a written change log.

3) Performance first
- Mapping must feel good at human speeds.
- Default macro ranges are tuned to "safe zones".
- Extremes are available but deliberate.

4) AI is advisory, offline
- AI may recommend macro assignments, curves, and ranges.
- AI never drives real-time controller motion.
- AI never modifies mappings without explicit human edits and a version bump.

5) Resample is a first-class action
- The system is designed to capture performances.
- Tweaking after the fact is allowed but not required to progress.

## 2. Hardware scope
- MPK Mini (any recent generation): keys + 8 pads + 8 knobs
- APC40 (mk1 or mk2): faders + knobs + clip matrix + transport

Degraded operation rules:
- MPK Mini alone must still allow basic bass writing and macro control.
- APC40 alone must still allow macro performance (no note entry).

## 3. Controller roles
### 3.1 MPK Mini = pitch and intent
- Keys: basslines, motifs, interval exploration.
- Pads: performance toggles (record/resample, mute, scene jump) or drum triggers (optional).
- Knobs: secondary macro access and/or sound-family offsets.

### 3.2 APC40 = energy shaping and commitment
- Faders: level and core macro intensities.
- Knobs: macro banks with predictable semantics.
- Buttons: arm, record, resample, commit, variation switching.

## 4. Ableton requirements for this layer
This layer assumes an Ableton set that follows these minimum conventions.

### 4.1 Tracks
- BASS_MAIN (instrument): Serum or Rack as primary bass engine
- BASS_RESAMPLE (audio): receives from BASS_MAIN post-FX
- BASS_PRINTS (audio): long-term printed takes (optional)
- SIDECHAIN_KEY (ghost kick / trigger) (optional)

### 4.2 Devices
- BASS_MAIN must expose 8 macros (Rack macros or Serum wrapped in a Rack).
- Macros follow the taxonomy (Macro 1..8).

### 4.3 Routing
- BASS_MAIN audio is capturable as-heard into BASS_RESAMPLE.
- All macro performance should be recordable as automation.

### 4.4 Banking assumption
- APC40 Bank A controls Macros 1-8.
- If additional banks exist, they must be explicitly documented and kept rare.

## 5. Mapping contract
### 5.1 Macro taxonomy is the contract
Every bass engine must map its internal parameters into the 8 macros with the same meaning.

Allowed variability:
- The exact parameter behind a macro may differ by sound family, but the perceptual role must remain consistent.

### 5.2 Safe zones
Default macro ranges must be tuned so that:
- 0-70% is musically usable most of the time.
- 70-100% is expressive / aggressive territory.

If a macro can easily kill the sound or create harsh clipping, clamp the default mapping range and expose "extreme" via a secondary control (shift, bank B, or a rack switch).

### 5.3 Curves
Use non-linear mapping where it improves feel:
- log-ish for filter cutoff / brightness
- exponential for drive
- S-curve for width

Curves are documented per macro per family (see AI workload output schema).

## 6. Calibration and test protocol
Before shipping a mapping version:

1) One-minute sweep test
- With a held note, sweep each macro from 0->100 and back.
- Confirm no dead zones and no discontinuities unless intentional.

2) Three gestures test
- Gesture 1: build (gradually intensify)
- Gesture 2: drop (sudden tighten + weight)
- Gesture 3: release (widen + soften)

3) Resample test
- Record 30 seconds of macro performance into BASS_RESAMPLE.
- Ensure the capture matches what was heard during play.

4) Voloco coexistence check
- Mapping does not demand constant attention.
- Macro roles are memorable enough to operate while also working vocals.

## 7. Versioning and change control
Mapping changes require:
- updated controllers/*_vX.Y.md files
- a short change log entry in controllers/README.md
- checksum regeneration

Do not silently change controller semantics.

## 8. AI integration (offline)
AI may produce a Controller Mapping Recommendation Bundle for a given corpus of past tracks:
- sound-family clusters
- suggested macro assignments
- suggested ranges and curves
- suggested APC40 bank layouts

The bundle is human-reviewed and then manually implemented in Ableton/Serum.

Reference: ai/workloads/AI_WORKLOAD_SPEC_v1.2_CONTROLLER_MAPPING.md
