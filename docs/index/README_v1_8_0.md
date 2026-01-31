# HVLIEN v1.8.0 — Index Build Bundle

Includes:
- JSON Schemas:
  - specs/index/artifact_index.v1.schema.json
  - specs/index/receipt_index.v1.schema.json
- CLI command group:
  - hvlien index build
  - hvlien index status

Wiring:
- Add `Index.self` to your CLI entrypoint (CliMain.swift or main.swift).
