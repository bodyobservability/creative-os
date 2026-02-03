# Robotics Operator - Profiles

This directory contains **Robotics Operator profiles**.

Robotics Operator is an operator persona for robotics workflows spanning:
- Jetson-class compute nodes (e.g., Orin Nano) for perception/planning
- Raspberry Pi nodes for distributed services and edge control
- ESP32 nodes for low-level sensing/actuation

Profiles here express **intent and safety policy**, not execution authority.

---

## What lives here

Robotics profiles may include:

- device/node inventories (what exists, where it is, how it is addressed)
- safety posture (arming rules, rate limits, e-stops as declared constraints)
- telemetry expectations (required sensors, units, sampling bounds)
- actuation intent (allowed command envelopes, not raw control code)
- operational notes and repeatable runbooks

Profiles do **not** contain:
- firmware or embedded code
- direct motor control logic
- hidden actuation paths that bypass plans/gates/receipts
- schema authority

All actuation must be planned, gated, and receipted by the kernel.

---

## Relationship to shared contracts

Robotics profiles are expected to reference:

- `/shared/contracts/robotics/devices/`
- `/shared/contracts/robotics/telemetry/`
- `/shared/contracts/robotics/actuation/`
- `/shared/contracts/robotics/safety/`

Shared contracts define truth across nodes and platforms.
Profiles select and constrain; they do not redefine.

---

## Evidence and receipts

Robotics workflows must leave evidence:

- plans that enumerate intended actions
- receipts for execution
- telemetry captures sufficient to diagnose behavior

If something moves, it must be auditable.

---

## Adding a new Robotics profile

When adding a profile:

1. Create a new subdirectory under this path.
2. Declare device inventory and safety posture explicitly.
3. Prefer shared contracts over local conventions.
4. Treat profiles as potentially high-consequence (robots can damage property or people).

If you need new semantics, add a shared contract, not a profile hack.
