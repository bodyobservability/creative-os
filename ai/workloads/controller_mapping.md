# Controller Mapping Workload (Offline)

Version: current

Status: Active

## 0. Purpose
This workload produces **recommendations** for:
- Macro assignments (Macro 1..8 per taxonomy)
- Macro ranges and curves tuned to "safe zones"
- Optional APC40 bank suggestions

It does NOT:
- drive real-time controller motion
- edit Ableton or Serum projects
- change mappings without human review

## 1. Inputs
### 1.1 Minimum corpus
- 20+ released or "completed" tracks is useful; 50+ is strong.
- Prefer stems or bass-focused renders when available.

### 1.2 Accepted material
- Full mixes (audio)
- Bass stems (preferred)
- MIDI clips (if available; optional)
- Automation exports (optional)

### 1.3 Audio specs
- 48 kHz preferred (match studio), 44.1 kHz acceptable
- WAV or AIFF preferred; MP3 acceptable only for similarity, not measurement

## 2. Core outputs
The workload outputs a **Controller Mapping Recommendation Bundle** directory:

```
ai/bundles/controller_mapping/current/<bundle_id>/
  mapping_bundle.json
  families.json
  features_summary.json
  curves.json
  examples/
    family_<name>_excerpts.wav
    family_<name>_spectra.png
  README.md
```

## 3. Feature extraction (bass-focused)
Goal: characterize *how Hvlien bass behaves* in perceptual terms.

Extract per-track (and per-segment) features:
- Sub-energy (20-80 Hz) over time
- Low-mid energy (80-250 Hz)
- Harmonic content / brightness (e.g., spectral centroid for 80-5k Hz)
- Spectral flux (movement)
- Roughness / distortion proxy (high-frequency energy + odd/even harmonic ratios)
- Stereo width proxy (mid/side energy above ~120 Hz)
- Transient sharpness proxy (attack slope, crest factor)

Segment tracks into meaningful bass sections (e.g., 4-16 bar segments) using:
- novelty / change-point detection on feature trajectories
- or beat-synchronous windowing if tempo is known

## 4. Family discovery (clustering)
Cluster segments into "sound families" that are useful in practice.

Constraints:
- Target 4-10 families (fewer is better if separable)
- Each family should have:
  - a short name
  - a one-sentence description
  - 2-6 example timestamps (or excerpt files)

Example family names (illustrative):
- WARM
- AGGRO
- HOLLOW
- GLASS
- MOVING
- SUBHEAVY

## 5. Macro inference and recommendations
Macro taxonomy is fixed (see `controllers/macro_taxonomy.md`).

For each family, recommend:
- which underlying device parameters should map to each macro
- default range (min/max) in normalized units
- curve type (linear/log/exp/s-curve)
- guardrails (clamps, compensating output trims)

### 5.1 Range suggestion heuristic
For each family and macro concept:
- use corpus distributions to set the safe zone to cover typical values
- set 0-70% to approximate 5th-80th percentile
- map 70-100% to the "expressive tail" up to ~95-99th percentile

If macro interacts strongly with loudness (e.g., DRIVE), recommend:
- inverse gain compensation
- limiter ceiling changes

### 5.2 Curve fitting
Choose curve type based on perceptual linearity:
- CUT and AIR: log-ish
- DRIVE and GRIT: exp
- WID: s-curve
- MOV and PUNCH: linear (unless evidence suggests otherwise)

Represent curves as either:
- named curve type with parameters, or
- sampled 0..1 lookup table of 128 or 256 points (preferred for reproducibility)

## 6. Output schema (mapping_bundle.json)
The bundle is a proposal the human implements manually.

Minimum JSON shape:

```json
{
  "bundle_version": "1.2",
  "generated_at": "YYYY-MM-DDThh:mm:ssZ",
  "corpus": {
    "num_tracks": 100,
    "num_segments": 620,
    "sample_rate_hz": 48000,
    "notes": "Bass stems preferred; some full mixes included"
  },
  "macro_taxonomy_version": "1.0",
  "families": [
    {
      "id": "WARM",
      "description": "Rounded, intimate bass with restrained distortion",
      "examples": [
        {"track": "<id>", "t0_sec": 42.1, "t1_sec": 57.9}
      ],
      "macro_recommendations": {
        "1": {"name": "CUT", "range": [0.12, 0.68], "curve": "log", "suggested_params": ["Serum.Filter.Cutoff"], "guardrails": ["avoid_silence"]},
        "2": {"name": "SUB", "range": [0.10, 0.55], "curve": "exp", "suggested_params": ["SubOsc.Level"], "guardrails": ["keep_sub_mono", "headroom"]}
      },
      "apc40_bank_suggestions": {
        "bank_a": "macros_1_to_8",
        "bank_b": "extremes_utilities_optional"
      }
    }
  ],
  "global_recommendations": {
    "default_macro_ranges": {
      "1": [0.10, 0.70],
      "2": [0.10, 0.60]
    },
    "notes": "Use output trim on DRIVE and GRIT to maintain headroom"
  }
}
```

## 7. Human review checklist
A bundle is acceptable only if:
- family set is understandable (not too many, not too abstract)
- macro meanings match the taxonomy
- recommended ranges are playable (no instant silence, no instant clipping)
- 3 gestures can be performed (build/drop/release) with 1-3 controls

## 8. Implementation handoff
The bundle is implemented by:
- updating Serum macro assignments (and/or wrapping Serum in a Rack)
- updating Ableton Rack macro mappings
- updating controller mappings (APC40 + MPK) only if taxonomy changes (rare)

After implementation:
- re-run checksum generation
- capture 3 short performance recordings per family
- store them as `library/demos/controller_layer_v1.0/*.wav`
