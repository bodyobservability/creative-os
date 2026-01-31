# v6.2 manifest target_track autopatch

This zip overwrites:
- specs/library/racks/rack_pack_manifest.v1.json

It adds explicit `target_track` for each rack (BassLead, Sub, MidGrowl, DrumBus)
so rack verify/install can select tracks deterministically (no heuristics).

Backward-compatible: tools that don't use target_track will ignore it.
