# Macro Taxonomy v1.0

This is the contract for bass performance control.

Every bass engine (Serum patch, Ableton Instrument Rack, Audio Effect Rack on bass bus) must expose **8 macros** with these stable meanings.

## Design goals
- Macros are **perceptual controls** (what you hear/feel), not engineering controls.
- 0-70% is the default "safe zone"; 70-100% is expressive / aggressive.
- Use curves to make the middle of the range playable.

## Macro table

| # | Short | Name | What it should feel like | Default curve | Safe zone guidance |
|---:|---|---|---|---|---|
| 1 | CUT | Cutoff / Brightness | opens/closes the sound without changing its identity | log-ish | clamp low end to avoid silence; avoid harsh whistling at top |
| 2 | SUB | Weight / Fundamental | adds chest and floor; more "mass" | gentle exp | prevent runaway low-end; keep headroom |
| 3 | DRIVE | Drive / Edge | saturation and bite; increases urgency | exp | keep 0-40% clean-ish; avoid hard clipping unless deliberate |
| 4 | MOV | Motion / Mod Depth | wobble, rhythmic motion, LFO depth, filter env amount | linear | keep subtle movement available 0-30% |
| 5 | WID | Width / Space | mono-to-wide; stereo interest without phase collapse | S-curve | keep low end mono; widen harmonics only |
| 6 | AIR | Air / Presence | top presence and articulation (not loudness) | log-ish | avoid brittle sibilant fizz at top |
| 7 | PUNCH | Punch / Transient | attack definition, compression behavior, pluck | linear | avoid clicky transient spikes unless intended |
| 8 | GRIT | Texture / Noise | texture layer, noise, FM grit, crushed detail | exp | ensure 0-20% is usable texture, not instant harshness |

## Suggested parameter mappings
These are defaults; sound families may vary as long as the perceptual meaning holds.

### Serum (typical)
- CUT: Filter cutoff (or global tone via EQ shelf) + modest filter drive
- SUB: Sub osc level or dedicated sine layer + multiband low band gain
- DRIVE: Distortion drive/mix (Soft Clip/Tube) + small output trim compensation
- MOV: LFO->filter amount, LFO rate (small), or Env2->wavetable position depth
- WID: Hyper/Dimension mix (high band only) or chorus width; keep sub mono
- AIR: High-shelf EQ gain OR noise brightness; can include reverb send (very subtle)
- PUNCH: Amp attack/decay (small), OTT depth (small), transient shaper amount
- GRIT: FM amount, bitcrush mix, noise level, or downsample amount

### Ableton (typical rack)
- CUT: Auto Filter cutoff + EQ8 tilt
- SUB: Utility gain for low band (post-split) + Saturator low boost
- DRIVE: Saturator drive + Pedal gain + limiter ceiling compensation
- MOV: Auto Filter env amount + LFO tool depth (if used)
- WID: Utility width (high band only) + chorus
- AIR: EQ8 high shelf + (optional) short room send
- PUNCH: Glue compressor threshold + transient shaper
- GRIT: Redux dry/wet + noise layer gain

## Implementation rules
1) A macro may control multiple parameters, but keep the mapping intuitive.
2) If a macro can destroy the sound, clamp its range and expose extremes via a secondary bank/shift.
3) Always include output trim compensation where needed (especially DRIVE).
4) Keep the number of moving parts low: prefer 1-3 parameters per macro.

## Acceptance tests
- Hold a note. Sweep each macro 0->100->0. No dead zones.
- Try three gestures: build, drop, release. Each gesture must be achievable with 1-3 controls.
