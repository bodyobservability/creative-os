# Creative OS

**Creative OS** is a personal, polymath operating system for building, operating, and closing complex creative and real-world workflows safely, reproducibly, and with evidence.

It is not a single app.
It is not a framework.
It is an execution substrate.

Creative OS exists to support a life that spans:
- music and studio work (Ableton, instruments, automation)
- textiles, fabrication, and physical artifacts
- robotics (Jetson, Raspberry Pi, ESP32 sensors/actuators)
- accounting and tax close-out (evidence, classification, exports)
- future domains that mix software, matter, and consequence

Core grammar:

> **plan -> gate -> execute -> receipt**

## What problem this solves

Most tools are built for one domain at a time. Real life is not.

Creative OS provides:
- deterministic execution
- safety gates
- immutable receipts
- epochal workflows for high-consequence close-outs

## Core concepts

### 1) The kernel
The kernel defines how actions happen, not what actions mean.

It provides:
- planning (preview before acting)
- gating (SAFE / GUIDED / ALL)
- allowlisted execution
- receipts and evidence
- governance and validation

### 2) Operator personas
Operator personas describe how a human works in a domain.

They:
- express intent and constraints
- bundle workflows/scripts/UI
- never execute directly
- are not authoritative

Current personas:
- Studio Operator
- Atelier Operator
- Robotics Operator
- Accounting Operator

### 3) Shared contracts
Shared contracts define truth across domains.

They are declarative, schema-validated, kernel-enforced, and execution-free.

## Repository layout

```text
kernel/
  cli/                 # Creative OS kernel entrypoint (wub)
  tools/               # validation, checksums, governance

operator/
  profiles/            # persona intent and policy (non-authoritative)
  packs/               # reusable artifact bundles
  notes/               # operator runbooks and workflows

shared/
  specs/               # authoritative schemas
  contracts/           # cross-domain contracts (materials, robotics, personas)

creative_os/
  launcher/            # repo-root TUI launcher
  shell/               # persona TUIs (Textual)

accounting/
  scripts/             # accounting logic (classification, exports, CI gates)

accounting/data/
  2025/
    intake/
    bundles/
    exports/
  _snapshots/

runs/
  <run_id>/            # plans, receipts, telemetry, evidence
```

Important: evidence lives under `accounting/data/` and is intentionally not committed.

## Getting started

Launcher (recommended):

```bash
make launcher
```

Accounting TUI:

```bash
make tui
```

Studio:

```bash
make studio
```

Bundle CLI (v0.1):

```bash
python3 -m creative_os.cli bundle --help
```

## Bundle support (v0.1)

Creative OS includes a local `cos bundle` workflow for importing and applying ship bundles.

Commands:

```bash
# import a bundle zip into the vault
python3 -m creative_os.cli bundle import /path/to/bundle.zip

# list and inspect imported bundles
python3 -m creative_os.cli bundle list
python3 -m creative_os.cli bundle show <bundle_id>

# plan then apply to a target repo
python3 -m creative_os.cli bundle plan <bundle_id> --target /path/to/target-repo
python3 -m creative_os.cli bundle apply <bundle_id> --target /path/to/target-repo --mode GUIDED --force
```

Vault location:
- default: `~/CreativeOSVault`
- override: `CREATIVE_OS_VAULT=/path/to/vault` or `--vault /path/to/vault`

Artifacts:
- imported bundles: `<vault>/memory/bundles/<YYYY>/<MM>/<bundle_id>/`
- import receipts: `<vault>/runs/<run_id>/bundle_import_receipt.v1.json`
- apply receipts: `<vault>/runs/<run_id>/bundle_apply_receipt.v1.json`
- apply/verify logs: `<vault>/runs/<run_id>/logs/`

## Safety model

Modes:
- SAFE: non-destructive actions only
- GUIDED: recommended actions, limited risk
- ALL: full power with explicit confirmation

If something moves money, machines, or matter, it must leave evidence.

## Governance and integrity

Key tools:

```bash
bash kernel/tools/checksum_generate.sh
bash kernel/tools/checksum_verify.sh
python kernel/tools/schema_validate.py
```

## Philosophy

Creative OS is a polymath operating system designed so adding domains is a content decision, not an architectural rewrite.

Read:
- `docs/shared/philosophy/polymath.md`

## Status

Creative OS is actively used. The architecture is intentionally conservative so it can support long-lived, high-consequence workflows.
