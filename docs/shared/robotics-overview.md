# Robotics Overview

Robotics Operator treats robots as stations composed of nodes:
Jetson, Raspberry Pi, and ESP32 devices are all modeled as **nodes** with contracts.

Creative OS remains the domain-agnostic execution kernel:
plan -> gate -> execute -> receipt.

Robotics expands Creative OS by expanding **contracts** and **evidence expectations**,
not by changing kernel semantics.

---

## Contract-first posture

- Devices are identified via `/shared/contracts/robotics/devices/`
- Telemetry schemas define unit-stable payloads under `/shared/contracts/robotics/telemetry/`
- Actuation is bounded and allowlisted under `/shared/contracts/robotics/actuation/`
- Safety gates and interlocks live under `/shared/contracts/robotics/safety/`

---

## Why Jetson + RPi + ESP32 fits

- Jetson: perception + planning + richer evidence
- Raspberry Pi: distributed services / edge control / networking
- ESP32: low-level sensors + actuators

All of them must:
- emit evidence
- obey gated actuation boundaries
- remain reproducible and auditable via receipts
