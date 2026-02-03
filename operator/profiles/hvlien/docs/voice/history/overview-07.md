# HVLIEN legacy — Ableton Assets (Build Kit)

## Why this is a "build kit" (not prebuilt .adg/.als binaries)
Ableton `.adg` and `.als` files are proprietary binary formats created by Ableton Live on a real machine.
In this environment I cannot run Ableton to author those binaries directly.

Instead, this bundle provides:
- a deterministic **recipe** to create the Control Rack and Template on your Mac (hands-free via Voice Control or minimal clicking),
- and a **verification plan** (v4 apply) to confirm the assets match the legacy mapping and Macro ABI.

Once you run the recipe on your machine, you will have real:
- `HVLIEN_VRL_ControlRack.adg`
- `HVLIEN_BASS_TEMPLATE_VRL.als`

## Outputs (expected)
- Ableton User Library:
  - Presets / Audio Effects Rack / `HVLIEN_VRL_ControlRack.adg`
  - Templates / `HVLIEN_BASS_TEMPLATE_VRL.als` (or your preferred template location)
