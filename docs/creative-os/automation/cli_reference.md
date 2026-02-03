# Wub Automation CLI Reference

This is the full CLI reference for automation operations. If you are operating in Studio Mode, prefer the Operator Shell (`make studio`) and use this only as needed.

## Display/profile setup
```bash
.build/release/wub regions-select --display 2560x1440 --config-dir kernel/cli/config
```

## Regions + anchors
```bash
.build/release/wub calibrate-regions --regions-config kernel/cli/config/regions.v1.json
.build/release/wub capture-anchor --regions-config kernel/cli/config/regions.v1.json --region browser.search
.build/release/wub validate-anchors --regions-config kernel/cli/config/regions.v1.json --pack /path/to/anchor_pack
```

## Plan/apply
```bash
.build/release/wub plan --json
.build/release/wub apply --plan /tmp/plan.json
```

## Racks + voice
```bash
.build/release/wub rack install --plan shared/specs/profiles/hvlien/voice/scripts/rack_pack_install.v1.yaml
.build/release/wub rack verify --plan shared/specs/profiles/hvlien/library/racks/verify_rack_pack.plan.v1.json
.build/release/wub voice verify --plan shared/specs/profiles/hvlien/voice/verify/verify_abi.plan.v1.json
```

## Voice runtime layer
```bash
.build/release/wub vrl validate --mapping shared/specs/profiles/hvlien/voice/runtime/vrl_mapping.v1.yaml
.build/release/wub midi list
.build/release/wub ui --anchors-pack shared/specs/automation/anchors/<pack_id>
```

## Index + drift
```bash
.build/release/wub index build
.build/release/wub index status
.build/release/wub drift check --anchors-pack-hint shared/specs/automation/anchors/<pack_id>
.build/release/wub drift plan --anchors-pack-hint shared/specs/automation/anchors/<pack_id>
.build/release/wub drift fix --anchors-pack-hint shared/specs/automation/anchors/<pack_id> --dry-run
```

## Ready + repair
```bash
.build/release/wub ready --anchors-pack-hint shared/specs/automation/anchors/<pack_id>
.build/release/wub repair --anchors-pack-hint shared/specs/automation/anchors/<pack_id>
```

## Export preflight
```bash
.build/release/wub assets preflight --anchors-pack shared/specs/automation/anchors/<pack_id>
```

## Asset exports
```bash
.build/release/wub assets export-racks --anchors-pack shared/specs/automation/anchors/<pack_id>
.build/release/wub assets export-performance-set --anchors-pack shared/specs/automation/anchors/<pack_id>
.build/release/wub assets export-finishing-bays --anchors-pack shared/specs/automation/anchors/<pack_id>
.build/release/wub assets export-serum-base --anchors-pack shared/specs/automation/anchors/<pack_id>
.build/release/wub assets export-extras --anchors-pack shared/specs/automation/anchors/<pack_id>
.build/release/wub assets export-all --anchors-pack shared/specs/automation/anchors/<pack_id> --overwrite
```

## Sonic + station
```bash
.build/release/wub sonic calibrate
.build/release/wub sonic sweep
.build/release/wub sonic tune
.build/release/wub station certify
```
