# Index Build Bundle

Version: current


Includes:
- JSON Schemas:
  - shared/specs/profiles/hvlien/index/artifact_index.v1.schema.json
  - shared/specs/profiles/hvlien/index/receipt_index.v1.schema.json
- CLI command group:
  - wub index build
  - wub index status

Wiring:
- Add `Index.self` to your CLI entrypoint (CliMain.swift or main.swift).
