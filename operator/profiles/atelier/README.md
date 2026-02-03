# Atelier Operator - Profiles

This directory contains **Atelier Operator profiles**.

Atelier Operator is an operator persona for textiles and fashion workflows:
materials-aware iteration, pattern planning, and receipted prototyping
without embedding domain semantics into the kernel.

These profiles are intentionally positioned between creative practice
and higher-consequence fabrication or medical-adjacent workflows.

---

## What lives here

Atelier profiles may include:

- material intent (e.g. stretch, drape, anisotropy) as **declared constraints**
- fit or form-factor intent
- pattern or fabrication planning preferences
- operator notes and iteration history
- references to shared material or manufacturing contracts

Profiles do **not** contain:
- material simulation logic
- fabrication execution logic
- schema authority
- assumptions about manufacturing devices

All execution semantics remain kernel-defined and safety-gated.

---

## Relationship to shared contracts

Atelier profiles are expected to reference:

- `/shared/specs/`
- `/shared/specs/profiles/<profile>/`
- `/shared/contracts/materials/`
- `/shared/contracts/manufacturing/` (when present)

Shared contracts define truth across domains.
Profiles express **selection and intent**, never authority.

---

## Evidence and receipts

Atelier workflows should emit receipts that support:

- reproducibility of a prototype build
- traceability from artifact back to intent
- bounded, auditable iteration

This preserves compatibility with future high-consequence domains
(e.g. medical textiles or assistive devices).

---

## Adding a new Atelier profile

When adding a new profile:

1. Create a new subdirectory under this path.
2. Declare material and fabrication intent explicitly.
3. Prefer references to shared contracts over local conventions.
4. Assume profiles may later be used in regulated contexts.

If a requirement cannot be expressed without new semantics,
it belongs in shared contracts -- not in the profile.
