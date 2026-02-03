# HVLIEN legacy — Runtime Mapping Validator Bundle

Contents:
- shared/specs/profiles/hvlien/voice/runtime/schemas/runtime_mapping_receipt.schema.v1.json
- kernel/cli/Sources/StudioCore/VRLValidateModels.swift
- kernel/cli/Sources/StudioCore/VRLValidateCommand.swift
- operator/profiles/hvlien/docs/voice/validator.md

Wiring:
- Add `VRL.self` to main.swift subcommands list.
  This enables: `wub vrl validate`
