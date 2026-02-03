import Foundation

struct ReadyAgent: CreativeOS.Agent {
  let id: String = "ready"
  let config: ReadyService.Config

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
    r.register(id: "ready_inputs") {
      let artifactOk = FileManager.default.fileExists(atPath: config.artifactIndex)
      let anchorsOk = FileManager.default.fileExists(atPath: config.anchorsPackHint)
      let ok = artifactOk && anchorsOk
      let observed: CreativeOS.JSONValue = .object([
        "artifact_index_exists": .bool(artifactOk),
        "anchors_pack_exists": .bool(anchorsOk)
      ])
      let expected: CreativeOS.JSONValue = .object([
        "artifact_index_exists": .bool(true),
        "anchors_pack_exists": .bool(true)
      ])
      return CreativeOS.CheckResult(id: "ready_inputs",
                                    agent: id,
                                    severity: ok ? .pass : .warn,
                                    category: .filesystem,
                                    observed: observed,
                                    expected: expected,
                                    evidence: [],
                                    suggestedActions: [CreativeOSActionCatalog.readyCheck.actionRef])
    }
  }

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let hint = config.anchorsPackHint
    let cmd = "wub ready --anchors-pack-hint \(hint)"
    let cfg = CreativeOSActionCatalog.readyCheckConfig(anchorsPackHint: hint,
                                                       artifactIndex: config.artifactIndex,
                                                       runDir: config.runDir,
                                                       writeReport: config.writeReport)
    p.register(id: "ready_check") {
      [CreativeOS.PlanStep(id: "ready_check",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [cfg, CreativeOS.Effect(id: "ready_check", kind: .process, target: cmd, description: "Run ready check")],
                           idempotent: true,
                           manualReason: "ready_check_required",
                           actionRef: CreativeOSActionCatalog.readyCheck.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
