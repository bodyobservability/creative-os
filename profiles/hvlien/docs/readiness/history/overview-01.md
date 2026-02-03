# Index Build Bundle

Version: v1.8.0


Includes:
- JSON Schemas:
  - profiles/hvlien/specs/index/artifact_index.v1.schema.json
  - profiles/hvlien/specs/index/receipt_index.v1.schema.json
- CLI command group:
  - wub index build
  - wub index status

Wiring:
- Add `Index.self` to your CLI entrypoint (CliMain.swift or main.swift).
