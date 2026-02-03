# Atelier Operator Overview

Atelier Operator is an operator persona for textiles and fashion workflows.
It exists to express **materials-aware intent** and to plan **fabrication-oriented iteration** without changing kernel semantics.

Atelier Operator is intentionally positioned between:
- purely aesthetic creative practice, and
- high-consequence medical / industrial practice.

The kernel remains domain-agnostic and authoritative.

---

## What Atelier Operator owns

Atelier Operator owns workflow affordances and vocabulary:
- materials-aware iteration (stretch, drape, anisotropy) as **declared constraints**
- pattern and fabrication planning
- export of artifacts (patterns, cut plans, parameter sets)
- operator notes and repeatable checklists

It may propose changes, but it does not execute authority.

---

## What Atelier Operator does *not* own

Atelier Operator does not own:
- execution semantics (plan/gate/execute/receipt)
- allowlists and actuation boundaries
- schema authority
- "hidden execution" or non-receipted mutation

---

## Evidence and receipts

Atelier workflows should produce receipts that support:
- reproducibility of a prototype build
- traceability of derived artifacts back to intent + inputs
- bounded changes (what changed, when, and why)

This preserves compatibility with future high-consequence workflows (e.g., medical-adjacent textiles).

---

## Where it lives

- Persona manifest:
  - `/shared/contracts/operator-persona/atelier-operator.manifest.json`
- Operator assets:
  - `/operator/profiles/atelier/`
  - `/operator/packs/atelier/`
  - `/operator/notes/atelier/`
- Shared contracts (future):
  - `/shared/contracts/materials/`
  - `/shared/contracts/manufacturing/`
  - `/shared/contracts/evidence/`

---

## Operating principle

Atelier Operator expands Creative OS by expanding **constraints and contracts**, not by expanding kernel semantics.
