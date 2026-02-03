# Robotics Operator - Packs

This directory contains **Robotics Operator packs**.

Packs bundle reusable robotics artifacts that support planning, deployment, and diagnosis
without embedding platform-specific logic into the kernel.

Packs are optional and non-authoritative.

---

## What lives here

Robotics packs may include:

- calibration artifacts (camera intrinsics, sensor offsets, baseline configs)
- launch templates and deployment bundles (declarative, inspectable)
- mapping or environment snapshots used for planning
- test scenarios and playback datasets
- operator documentation and runbooks scoped to a pack

Packs do **not** contain:
- privileged execution logic
- firmware images or secret material
- direct actuation scripts that bypass kernel gating
- schema authority

---

## Relationship to contracts and profiles

- Profiles select and constrain packs.
- Packs reference shared robotics contracts for device IDs, telemetry schemas, and safety gates.
- Any pack that influences execution must be reflected in plans and traceable in receipts.

A pack is a **repeatable context bundle**, not a source of truth.

---

## Adding a new Robotics pack

When adding a pack:

1. Create a new subdirectory under this path.
2. Keep artifacts declarative and reviewable.
3. Externalize platform semantics into shared contracts (Jetson/RPi/ESP32 are just nodes).
4. Assume packs may be reused across different robots.

If it needs execution semantics, it belongs in the kernel, but that is a high bar.
