import Foundation

struct ProfileAgent: CreativeOS.Agent {
  let id: String = "profile"
  let profile: CreativeOS.Profile

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}
  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {}

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(profile.id),
      "intents": .array(profile.intents.map { .string($0) }),
      "policies": .object(profile.policies),
      "requirements": .object(profile.requirements),
      "packs": .array(profile.packs.map { .string($0) })
    ])
    return CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: json)
  }
}

struct PackAgent: CreativeOS.Agent {
  let pack: CreativeOS.PackManifest

  var id: String { "pack:\(pack.id)" }

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}
  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {}

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(pack.id),
      "applies_to": .array(pack.appliesTo.map { .string($0) }),
      "contents": .object(pack.contents),
      "requires_explicit_apply": .bool(pack.requiresExplicitApply)
    ])
    return CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: json)
  }

  func desiredState() throws -> CreativeOS.DesiredStateSlice? {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(pack.id),
      "applies_to": .array(pack.appliesTo.map { .string($0) }),
      "contents": .object(pack.contents),
      "requires_explicit_apply": .bool(pack.requiresExplicitApply)
    ])
    return CreativeOS.DesiredStateSlice(agentId: id, data: nil, raw: json)
  }
}

struct MappingAgent: CreativeOS.Agent {
  let id: String = "runtime"

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
    let issues = CreativeOSMapping.validate()
    guard !issues.isEmpty else { return }
    r.register(id: "migration_mapping_validation") {
      CreativeOS.CheckResult(id: "migration_mapping_validation",
                             agent: id,
                             severity: .warn,
                             category: .policy,
                             observed: .array(issues.map { .string($0) }),
                             expected: nil,
                             evidence: [
                               CreativeOS.EvidenceItem(id: "mapping_table", kind: "mapping", path: "docs/creative_os_mapping.md", details: nil)
                             ],
                             suggestedActions: [])
    }
  }

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let issues = CreativeOSMapping.validate()
    guard !issues.isEmpty else { return }
    p.register(id: "migration_mapping_validation") {
      [CreativeOS.PlanStep(id: "migration_mapping_validation",
                           agent: id,
                           type: .manualRequired,
                           description: "Resolve migration mapping validation issues",
                           effects: [],
                           idempotent: true,
                           manualReason: "mapping_validation")]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}

struct SweeperConfig {
  let anchorsPack: String?
  let modalTest: String
  let requiredControllers: [String]
  let allowOcrFallback: Bool
  let fix: Bool
}

struct DriftConfig {
  let anchorsPackHint: String?
}

struct ReadyConfig {
  let anchorsPackHint: String
}

struct SweeperAgent: CreativeOS.Agent {
  let id: String = "sweeper"
  let config: SweeperConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = buildCommand()
    p.register(id: "sweep_legacy") {
      [CreativeOS.PlanStep(id: "sweep_legacy",
                           agent: id,
                           type: .manualRequired,
                           description: "Run: \(cmd)",
                           effects: [CreativeOS.Effect(id: "sweep_command", kind: .process, target: cmd, description: "Run legacy sweep")],
                           idempotent: true,
                           manualReason: "legacy_sweep")]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }

  private func buildCommand() -> String {
    var args: [String] = ["wub", "sweep-legacy"]
    if let anchorsPack = config.anchorsPack, !anchorsPack.isEmpty {
      args += ["--anchors-pack", anchorsPack]
    }
    if !config.modalTest.isEmpty {
      args += ["--modal-test", config.modalTest]
    }
    if config.allowOcrFallback {
      args.append("--allow-ocr-fallback")
    }
    if config.fix {
      args.append("--fix")
    }
    for controller in config.requiredControllers {
      args += ["--require-controller", controller]
    }
    return args.joined(separator: " ")
  }
}

struct DriftAgent: CreativeOS.Agent {
  let id: String = "drift"
  let config: DriftConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let hint = config.anchorsPackHint ?? ""
    let checkCmd = hint.isEmpty ? "wub drift check" : "wub drift check --anchors-pack-hint \(hint)"
    let planCmd = hint.isEmpty ? "wub drift plan" : "wub drift plan --anchors-pack-hint \(hint)"
    let fixCmd = hint.isEmpty ? "wub drift fix --dry-run" : "wub drift fix --anchors-pack-hint \(hint) --dry-run"

    p.register(id: "drift_check") {
      [CreativeOS.PlanStep(id: "drift_check",
                           agent: id,
                           type: .manualRequired,
                           description: "Run: \(checkCmd)",
                           effects: [CreativeOS.Effect(id: "drift_check", kind: .process, target: checkCmd, description: "Run drift check")],
                           idempotent: true,
                           manualReason: "legacy_drift_check")]
    }
    p.register(id: "drift_plan") {
      [CreativeOS.PlanStep(id: "drift_plan",
                           agent: id,
                           type: .manualRequired,
                           description: "Run: \(planCmd)",
                           effects: [CreativeOS.Effect(id: "drift_plan", kind: .process, target: planCmd, description: "Run drift plan")],
                           idempotent: true,
                           manualReason: "legacy_drift_plan")]
    }
    p.register(id: "drift_fix") {
      [CreativeOS.PlanStep(id: "drift_fix",
                           agent: id,
                           type: .manualRequired,
                           description: "Run: \(fixCmd)",
                           effects: [CreativeOS.Effect(id: "drift_fix", kind: .process, target: fixCmd, description: "Run drift fix (dry run)")],
                           idempotent: true,
                           manualReason: "legacy_drift_fix")]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}

struct ReadyAgent: CreativeOS.Agent {
  let id: String = "ready"
  let config: ReadyConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let hint = config.anchorsPackHint
    let cmd = "wub ready --anchors-pack-hint \(hint)"
    p.register(id: "ready_check") {
      [CreativeOS.PlanStep(id: "ready_check",
                           agent: id,
                           type: .manualRequired,
                           description: "Run: \(cmd)",
                           effects: [CreativeOS.Effect(id: "ready_check", kind: .process, target: cmd, description: "Run ready check")],
                           idempotent: true,
                           manualReason: "legacy_ready_check")]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
