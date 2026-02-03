# Atelier Operator - Packs

This directory contains **Atelier Operator packs**.

Atelier packs bundle **material- and fabrication-adjacent artifacts**
that support textiles and fashion workflows without changing kernel semantics.

They are designed for iteration, comparison, and reproducibility.

---

## What lives here

Atelier packs may include:

- pattern templates or parameter sets
- material swatch references (metadata, not simulation)
- fabrication planning helpers
- example artifacts used for prototyping
- operator-facing documentation for repeatable builds

Packs do **not** contain:
- material simulation engines
- fabrication execution logic
- manufacturing device assumptions
- schema authority

---

## Relationship to shared contracts

Atelier packs are expected to reference:

- `/shared/contracts/materials/`
- `/shared/contracts/manufacturing/` (when present)
- `/shared/specs/`

Shared contracts define truth.
Packs express **contextual selection and reuse**, not authority.

---

## Evidence and receipts

Atelier packs should support:

- traceable artifact generation
- reproducible fabrication planning
- comparison across iterations

If a pack materially affects a build, that effect should be visible in receipts.

This ensures compatibility with future Lab or Clinic workflows.

---

## Adding a new Atelier pack

When adding a pack:

1. Create a new subdirectory under this path.
2. Declare assumptions explicitly (materials, tolerances, intent).
3. Prefer references to shared contracts over local conventions.
4. Assume the pack may later be used in higher-consequence contexts.

If a requirement cannot be expressed declaratively, it belongs in shared contracts - not in the pack.
