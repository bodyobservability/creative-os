# HVLIEN v9.4 — Runtime Mapping Validator Bundle

Contents:
- specs/voice_runtime/schemas/v9_4_runtime_mapping_receipt.v1.schema.json
- tools/automation/swift-cli/Sources/hvlien/VRLValidateModels.swift
- tools/automation/swift-cli/Sources/hvlien/VRLValidateCommand.swift
- docs/voice_runtime/v9_4_validator.md

Wiring:
- Add `VRL.self` to main.swift subcommands list.
  This enables: `hvlien vrl validate`
