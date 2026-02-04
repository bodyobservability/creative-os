# Creative OS

**Creative OS** is a **domain-agnostic execution kernel** for building, operating, and evolving creative and physical systems safely.

It provides a single execution grammar:

> **plan -> gate -> execute -> receipt**

...and applies it consistently across:
- music and studio automation
- textiles and fabrication
- robotics (Jetson, Raspberry Pi, ESP32)
- future material- and body-coupled systems

Creative OS is designed so new domains add **contracts and personas**, not kernel rewrites.

---

## What this repository is

This repository contains the **Creative OS kernel**, its **operator personas**, and the **shared contracts** that allow polymath expansion without architectural drift.

It is intentionally **not**:
- a single application
- a domain-specific framework
- a collection of scripts

It is an execution substrate.

---

## Accounting & launcher

This repo also ships a **Textual launcher** and an **Accounting TUI**:

```bash
make shell-install
make launcher
```

Run the accounting flow directly:

```bash
make tui
```

Accounting specs and docs live here:

* `shared/specs/accounting/`
* `docs/accounting/CREATIVE_OS_ACCOUNTING_QUICKSTART.md`

---

## Core concepts

### Kernel
The kernel defines **how things happen**, not **what things are**.

- deterministic planning
- safety gating
- allowlisted execution
- immutable receipts
- governance and validation

The kernel never embeds domain semantics.

---

### Operator personas
Operator personas define **how humans think and work**, not how execution works.

Current personas:
- **Studio Operator** -- studio workflows, automation, voice/TUI
- **Atelier Operator** -- textiles, materials, fabrication planning
- **Robotics Operator** -- robots, sensors, telemetry, gated actuation

Personas are parallel and non-authoritative.
They express **intent and constraints**, not execution power.

---

### Shared contracts
Shared contracts define **truth across domains**.

They are:
- declarative
- schema-validated
- enforced by the kernel
- free of execution logic

Contracts currently include:
- operator persona manifests
- materials
- robotics (devices, telemetry, actuation, safety)

This is where new domains integrate.

---

## Repository layout

```text
kernel/
  cli/                 # Creative OS kernel entrypoint (wub)
  tools/               # kernel-owned tooling (validation, checksums, hooks)

operator/
  profiles/            # persona-specific intent & policy
  packs/               # reusable, non-authoritative artifact bundles
  notes/               # operator workflows & runbooks

shared/
  specs/               # authoritative schemas and specs
  contracts/           # cross-domain contracts (materials, robotics, etc.)

docs/
  creative-os/         # kernel docs (execution, safety, governance)
  studio-operator/     # Studio Operator docs
  accounting/          # accounting QuickStart + TUI docs
  shared/              # system-wide docs (philosophy, release, compliance)

accounting/
  scripts/             # accounting helpers (autofill, exports, CI)

runs/
  <run_id>/            # plans, receipts, evidence, telemetry
```

---

## First run

```bash
make onboard
```

This performs a gated preflight and produces receipts under `runs/`.

See:

* `docs/studio-operator/first-run.md`

---

## Build the CLI

```bash
cd kernel/cli
swift build -c release
```

Run core commands:

```bash
kernel/cli/.build/release/wub sweep
kernel/cli/.build/release/wub plan --json
kernel/cli/.build/release/wub setup --show-manual
```

---

## Safety model (read before execution)

* All mutating actions are **planned** and **gated**
* Only allowlisted actions execute
* Every execution emits **receipts**
* Evidence and telemetry are captured under `runs/<run_id>/`

If something moves, changes, or actuates, it must leave evidence.

---

## Robotics posture

Robotics is treated as a **first-class domain**, not a special case.

* Jetson, Raspberry Pi, and ESP32 devices are modeled as **nodes**
* Sensors emit schema-validated telemetry
* Actuation is bounded, allowlisted, and receipted
* Safety gates and interlocks are declarative contracts

See:

* `shared/contracts/robotics/`
* `docs/shared/robotics-overview.md`

---

## Governance and validation

Creative OS enforces its invariants automatically:

* kernel must not reference operator paths
* checksums are deterministic
* schemas and contracts are validated
* operator persona manifests are enforced

Key tools:

```bash
bash kernel/tools/checksum_generate.sh
bash kernel/tools/checksum_verify.sh
python kernel/tools/schema_validate.py
bash kernel/tools/validate_persona_manifests.sh
```

---

## Philosophy

Creative OS is a **polymath operating system**.

It is designed so that:

* adding a new domain is a content decision
* not an architectural refactor

Read:

* `docs/shared/philosophy/polymath.md`

---

## Contributing

Before contributing, read:

* `CONTRIBUTING.md`

Invariants are non-negotiable:

* kernel neutrality
* persona non-authority
* contract-first integration
* no hidden execution paths

---

## Roadmap

The canonical roadmap lives at:

* `docs/creative-os/ROADMAP.md`

Operator-specific roadmaps live alongside their personas.

---

## Status

Creative OS is under active development.
The architecture is intentionally conservative so it can support long-lived, high-consequence systems.

Exploration is encouraged.
Entropy is not.
