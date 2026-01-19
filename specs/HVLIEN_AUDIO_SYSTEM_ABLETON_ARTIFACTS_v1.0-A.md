# HVLIEN AUDIO SYSTEM — ABLETON ARTIFACTS
## SPEC v1.0-A (EXTENSION)

This document specifies the required Ableton artifacts and their canonical structure.

---

## 1. ABLETON ARTIFACT INVENTORY (REQUIRED)

### Ableton Project Files
- `ableton/finishing-bays/HVLIEN_FINISHING_BAY_v1.als`
- `ableton/finishing-bays/HVLIEN_FINISHING_BAY_DARK.als`
- `ableton/finishing-bays/HVLIEN_FINISHING_BAY_LIGHT.als`

---

## 2. GLOBAL PREFERENCES (MUST MATCH)

| Setting | Value |
|------|------|
| Sample Rate | 48 kHz |
| Record Bit Depth | 24-bit |
| Auto-Warp Long Samples | OFF |
| Default Warp Mode | OFF |
| Reduced Latency When Monitoring | ON |
| Plug-In Delay Compensation | ON |
| CPU Multicore | ON |
| File Save Compression | OFF |
| Arrangement Loop | OFF |

---

## 3. PRIMARY FINISHING BAY — DETAIL

### File
`HVLIEN_FINISHING_BAY_v1.als`

### Track Layout (Exact)
- `VOLOCO_STEM` (Audio) → `MUSIC_BUS` (Group) → Master
- `LOW_CONTROL` (Audio, sends only, muted) for sidechain reference
- `MASTER_PRINT` (Audio, resampling) to print final pass

### VOLOCO_STEM
- Warp OFF
- No edits, automation, fades, clip gain

### MUSIC_BUS Device Stack (fixed order)
1. EQ Eight: HPF 30–35 Hz (subtractive only)
2. Glue Compressor: 2:1, Attack 10ms, Release Auto, 1–2 dB GR max
3. Saturator: Soft Clip ON, Drive 1–3 dB, Dry/Wet ~85%
4. Utility: Bass Mono <120 Hz, Width 100%
5. Limiter: Ceiling -1.0 dBFS, minimal gain

### Export preset
- WAV, 24-bit, 48kHz
- Normalize OFF
- Dither OFF

---

## 4. DARK BAY — DELTA

### File
`HVLIEN_FINISHING_BAY_DARK.als`

Allowed deltas only:
- Saturator Drive: +0.5 to +1 dB vs Primary
- Glue Release: ~300 ms (fixed)
- Utility Width: 95–98%
- Limiter gain: slightly reduced

No structural changes.

---

## 5. LIGHT BAY — DELTA

### File
`HVLIEN_FINISHING_BAY_LIGHT.als`

Allowed deltas only:
- Saturator Drive: -0.5 to -1 dB vs Primary
- Glue Release: ~120 ms
- Utility Width: 102–105%
- Slightly more headroom (less limiter input)

No structural changes.

---

## 6. VERSIONING

Allowed:
- value tuning (thresholds, timing constants, small gain offsets)

Forbidden:
- routing changes
- device insertion/removal
- per-track edits

Structural change requires bump:
- `..._v1.1.als`

---

# END SPEC v1.0-A
