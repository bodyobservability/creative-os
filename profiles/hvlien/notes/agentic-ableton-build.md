# AGENTIC_ABLETON_BUILD.md
## Spec-driven, agent-guided creation of Ableton `.als` artifacts (macOS)

This repo intentionally ships **placeholder** `.als` files. Real Ableton Live Sets must be created inside Ableton on macOS.
Ableton Live Set files are binary and not safely generated headlessly.

This document defines the **supported agentic workflow**: ChatGPT acts as a build agent; you execute deterministic steps in Ableton.

---

## 1) What is and isn’t possible

### Not supported / not reliable
- Directly generating `.als` files from text
- Headless Ableton authoring via CLI
- UI automation scripts as the primary build mechanism (fragile across versions)

### Supported (recommended)
- **Spec-Driven Interactive Build (SDIB)**: human-in-the-loop, agent-guided, deterministic steps.
- Resulting `.als` files are then checksummed and committed.

---

## 2) Build prerequisites (macOS)

- Ableton Live Suite installed (latest stable)
- Repo checked out locally
- Global Ableton prefs set per `profiles/hvlien/specs/creative_os_audio_system_ableton_artifacts_v1.0-a.md`
- AUDIO4c not required to build bays (drag-drop WAV is sufficient)

---

## 3) Agentic build protocol (how to use ChatGPT)

Open ChatGPT (desktop app or browser) and start a build session:

**Prompt template:**
```
You are the build agent. We are constructing Ableton artifacts exactly per:
profiles/hvlien/specs/creative_os_audio_system_ableton_artifacts_v1.0-a.md

Artifact to build: <FILENAME>
Mode: Deterministic SDIB (one atomic step at a time).
Stop and ask if anything deviates.
```

### Execution rules
- Agent provides **one atomic action** at a time (e.g., "Create audio track named VOLOCO_STEM").
- You perform it and respond: `done`.
- Agent proceeds to next step.
- If any UI differs (Ableton version differences), you describe the menu name you see and the agent adapts **without changing the spec**.

---

## 4) Build checklist for each finishing bay

### 4.1 Primary Bay: `HVLIEN_FINISHING_BAY.als`
Follow `profiles/hvlien/specs/creative_os_audio_system_ableton_artifacts_v1.0-a.md`, Section 3.

Must verify:
- Tracks exist with exact names:
  - VOLOCO_STEM
  - LOW_CONTROL
  - MASTER_PRINT
  - Group: MUSIC_BUS
- Warp disabled globally + per-clip default
- MUSIC_BUS device order:
  1) EQ Eight (HPF 30–35Hz)
  2) Glue Compressor (2:1, Attack 10ms, Release Auto, 1–2dB GR max)
  3) Saturator (Soft Clip, Drive 1–3dB, Dry/Wet ~85%)
  4) Utility (Bass Mono <120Hz, Width 100%)
  5) Limiter (Ceiling -1.0dBFS)
- Export preset exists (WAV 24-bit 48kHz, Normalize OFF, Dither OFF)

### 4.2 Dark Bay: `HVLIEN_FINISHING_BAY_DARK.als`
Clone from Primary and apply deltas only (no structural changes):
- Saturator Drive: +0.5 to +1dB vs Primary
- Glue Release: fixed ~300ms
- Utility Width: 95–98%
- Limiter input: slightly reduced

### 4.3 Light Bay: `HVLIEN_FINISHING_BAY_LIGHT.als`
Clone from Primary and apply deltas only:
- Saturator Drive: -0.5 to -1dB vs Primary
- Glue Release: ~120ms
- Utility Width: 102–105%
- Slightly more headroom

---

## 5) Post-build: replace placeholders, regenerate checksums, commit

1. Save each `.als` into:
   - `packs/hvlien-defaults/ableton/finishing-bays/`
   - Overwrite the placeholder file.
2. Recompute checksums:
   ```bash
   tools/checksum_generate.sh
   ```
3. Verify:
   ```bash
   tools/checksum_verify.sh
   ```
4. Commit:
   ```bash
   git add .
   git commit -m "Add real Ableton finishing bays (.als) per spec v1.0-A"
   ```

---

## 6) Optional hardening (recommended later)
- Add a Max for Live verification device to detect drift:
  - track names, routing, device order, key parameters
- Keep it out of the finishing bays until after v1.0 is stable.

---

# END
