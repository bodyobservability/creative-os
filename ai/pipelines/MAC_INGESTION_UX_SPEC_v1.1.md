# MAC_INGESTION_UX_SPEC_v1.1

Goal: ingest AI outputs without adding drag or new UI dependencies.

## 1) Bundle inbox (Mac)
- `/HVLIEN/AI/inbox/<TrackID>/`
Bundles must arrive atomically (stage then rename).

## 2) Engineer-only action model
Allowed actions:
1) Accept bay recommendation -> open that bay -> one-pass print.
2) Ignore recommendation -> use Primary -> one-pass print.
3) Promote to deeper production -> only if promotion rules pass.

## 3) Minimal UI surfaces
- Finder folder view
- Optional markdown report rendered from report.json

## 4) Provenance
Bundles must include:
- source SHA-256
- model versions
- timestamp
- confidence

---

# END
