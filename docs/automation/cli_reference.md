# HVLIEN Automation CLI Reference

This is the full CLI reference for automation operations. If you are operating in Studio Mode, prefer the Operator Shell (`make studio`) and use this only as needed.

## Display/profile setup
```bash
.build/release/hvlien regions-select --display 2560x1440 --config-dir tools/automation/swift-cli/config
```

## Regions + anchors
```bash
.build/release/hvlien calibrate-regions --regions-config tools/automation/swift-cli/config/regions.v1.json
.build/release/hvlien capture-anchor --regions-config tools/automation/swift-cli/config/regions.v1.json --region browser.search
.build/release/hvlien validate-anchors --regions-config tools/automation/swift-cli/config/regions.v1.json --pack /path/to/anchor_pack
```

## Plan/apply
```bash
.build/release/hvlien plan --in /path/to/specs --out /tmp/plan.json
.build/release/hvlien apply --plan /tmp/plan.json
```

## Racks + voice
```bash
.build/release/hvlien rack install --plan specs/voice/scripts/rack_pack_install.v1.yaml
.build/release/hvlien rack verify --plan specs/library/racks/verify_rack_pack.plan.v1.json
.build/release/hvlien voice verify --plan specs/voice/verify/verify_abi.plan.v1.json
```

## Voice runtime layer
```bash
.build/release/hvlien vrl validate --mapping specs/voice_runtime/v9_3_ableton_mapping.v1.yaml
.build/release/hvlien midi list
.build/release/hvlien ui --anchors-pack specs/automation/anchors/<pack_id>
```

## Index + drift
```bash
.build/release/hvlien index build
.build/release/hvlien index status
.build/release/hvlien drift check --anchors-pack-hint specs/automation/anchors/<pack_id>
.build/release/hvlien drift plan --anchors-pack-hint specs/automation/anchors/<pack_id>
.build/release/hvlien drift fix --anchors-pack-hint specs/automation/anchors/<pack_id> --dry-run
```

## Ready + repair
```bash
.build/release/hvlien ready --anchors-pack-hint specs/automation/anchors/<pack_id>
.build/release/hvlien repair --anchors-pack-hint specs/automation/anchors/<pack_id>
```

## Export preflight
```bash
.build/release/hvlien assets preflight --anchors-pack specs/automation/anchors/<pack_id>
```

## Asset exports
```bash
.build/release/hvlien assets export-racks --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-performance-set --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-finishing-bays --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-serum-base --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-extras --anchors-pack specs/automation/anchors/<pack_id>
.build/release/hvlien assets export-all --anchors-pack specs/automation/anchors/<pack_id> --overwrite
```

## Sonic + station
```bash
.build/release/hvlien sonic calibrate
.build/release/hvlien sonic sweep
.build/release/hvlien sonic tune
.build/release/hvlien station certify
```
