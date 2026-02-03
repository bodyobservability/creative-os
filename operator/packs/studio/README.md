# Studio Operator - Packs

This directory contains **Studio Operator packs**.

Packs are optional, attachable artifacts that support studio workflows.
They are not authoritative and do not execute logic.

Packs exist to bundle **creative artifacts**, presets, and references
that can be selected by profiles and validated by the kernel.

---

## What lives here

Studio packs may include:

- presets or templates (e.g. racks, scenes, routing layouts)
- reference assets (audio, metadata, indices)
- operator-facing helpers that influence planning
- documentation or notes scoped to the pack

Packs do **not** contain:
- execution logic
- allowlists or safety rules
- schema definitions
- hard-coded assumptions about kernel behavior

---

## Relationship to profiles and specs

- Profiles **select and reference** packs.
- Packs may reference shared specs or contracts but do not override them.
- All execution remains kernel-gated and receipted.

A pack is a *suggestion bundle*, not a source of truth.

---

## Evidence and receipts

When a pack influences a mutating workflow:
- its use should be visible in the plan
- its effects should be traceable in receipts

If a pack materially affects output, that fact should be auditable.

---

## Adding a new Studio pack

When adding a pack:

1. Create a new subdirectory under this path.
2. Keep contents declarative and inspectable.
3. Avoid embedding domain assumptions that belong in shared contracts.
4. Assume packs may be reused across multiple profiles.

If a pack requires new semantics, they belong in shared specs or contracts - not in the pack itself.
