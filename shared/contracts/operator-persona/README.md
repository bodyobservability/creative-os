# Operator Persona Contract

An operator persona is a workflow lens and vocabulary that drives Creative OS without changing kernel semantics.

The kernel remains domain-agnostic and authoritative:
- plans are explicit
- execution is gated
- receipts are immutable
- operator assets are non-authoritative without kernel validation

Each persona must provide a manifest that declares:
- identity and intent
- asset roots (profiles/packs/notes/docs entrypoints)
- required receipts (evidence expectations for mutating workflows)
- declared capabilities (strings; not logic)

Manifests are contracts, not marketing.
