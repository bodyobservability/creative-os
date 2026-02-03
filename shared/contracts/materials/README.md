# Materials Contracts

This directory defines **authoritative material contracts** used across operator personas.

Materials contracts describe properties, constraints, and identifiers for physical materials.
They contain no execution logic and no simulation code.

They are validated and enforced by the Creative OS kernel.

---

## Purpose

Materials contracts exist to:

- give materials stable, inspectable identities
- express properties as constraints, not behavior
- support reproducibility across creative and fabrication workflows
- scale from textiles to medical-adjacent materials without semantic drift

---

## What belongs here

- material identity schemas
- property descriptors (e.g. stretch, stiffness, breathability)
- tolerance ranges
- references to external standards (when applicable)

---

## What does not belong here

- simulation or physics engines
- fabrication logic
- device-specific instructions
- operator-specific assumptions

---

## Expected evolution

This directory may later include:

- textile-specific contracts
- polymer or composite contracts
- biocompatibility descriptors
- wash / sterilization tolerance descriptors

All such additions must remain declarative and domain-agnostic.
