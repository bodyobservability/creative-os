# Studio Operator - Profiles

This directory contains **Studio Operator profiles**.

Studio Operator is an operator persona for studio workflows:
planning, safety-gated execution, and receipted iteration across studio stations.

Profiles in this directory express **operator intent and policy**, not execution authority.

---

## What lives here

Studio profiles may include:

- identity and role information
- operator preferences and workflow policy
- station configuration intent
- profile-specific notes and checklists
- references to shared specs and contracts

Profiles do **not** contain:
- execution logic
- allowlists
- schema authority
- hardcoded paths to kernel internals

All execution is validated and authorized by the Creative OS kernel.

---

## Relationship to shared specs

Studio profiles may reference:

- `/shared/specs/`
- `/shared/specs/profiles/<profile>/`

Shared specs are authoritative and validated by the kernel.
Profiles may narrow or select from shared specs, but may not override them implicitly.

---

## Evidence and receipts

Mutating studio workflows produce receipts under `runs/<run_id>/`.
Profiles should be written assuming that:
- plans are explicit
- actions are gated
- receipts are immutable

If a change matters, it must leave evidence.

---

## Adding a new Studio profile

When adding a new profile:

1. Create a new subdirectory under this path.
2. Declare intent and policy clearly.
3. Reference shared specs/contracts explicitly.
4. Avoid embedding domain assumptions into filenames or structure.

If a profile requires new semantics, they belong in shared contracts -- not in the profile itself.
