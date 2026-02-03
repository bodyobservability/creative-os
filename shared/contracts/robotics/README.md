# Robotics Contracts

`shared/contracts/robotics/` defines **cross-platform contracts** for robotics workflows
across Jetson, Raspberry Pi, and ESP32 nodes.

These contracts are declarative:
- no execution logic
- no platform-specific code
- no hidden behavior

They exist so the kernel can validate inputs and enforce safety gates consistently,
while operator personas remain free to evolve.

---

## Subtrees

- `devices/`
  - node identities, roles, addressing, capabilities (Jetson/RPi/ESP32 are all nodes)
- `telemetry/`
  - schema for sensor payloads, units, timestamps, sampling bounds
- `actuation/`
  - schema for allowed commands (bounded envelopes, rate limits)
- `safety/`
  - gate definitions, arming rules, e-stop semantics, interlocks (declarative)

---

## Design rules

1. Contracts describe **what** and **bounds**, never **how**.
2. All actuation must be expressible as allowlisted actions and must be receipted.
3. Telemetry must be unit-stable and timebase-explicit (monotonic if possible).
4. The same contracts must support low-consequence (plant watering) and higher-consequence (drones) workflows.

---

## Expected evolution

This taxonomy supports:
- robot cars and drones (higher consequence)
- environmental monitoring (lower consequence)
- distributed sensor/actuator networks (many ESP32 nodes)
without changing kernel semantics.

Optional next: add tiny schemas later (node.schema.json, telemetry.sample.schema.json, etc.), but the skeleton alone is already high leverage.
