# HVLIEN legacy — Runtime Mapping Validator Bundle

Contents:
- profiles/hvlien/specs/voice/runtime/schemas/runtime_mapping_receipt.schema.v1.json
- tools/automation/swift-cli/Sources/StudioCore/VRLValidateModels.swift
- tools/automation/swift-cli/Sources/StudioCore/VRLValidateCommand.swift
- profiles/hvlien/docs/voice/validator.md

Wiring:
- Add `VRL.self` to main.swift subcommands list.
  This enables: `wub vrl validate`
