import Foundation

struct RepairAgent: CreativeOS.Agent {
  let id: String = "repair"
  let config: RepairService.Config

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
    r.register(id: "repair_inputs") {
      let anchorsOk = FileManager.default.fileExists(atPath: config.anchorsPackHint)
      let observed: CreativeOS.JSONValue = .object([
        "anchors_pack_exists": .bool(anchorsOk)
      ])
      let expected: CreativeOS.JSONValue = .object([
        "anchors_pack_exists": .bool(true)
      ])
      return CreativeOS.CheckResult(id: "repair_inputs",
                                    agent: id,
                                    severity: anchorsOk ? .pass : .warn,
                                    category: .filesystem,
                                    observed: observed,
                                    expected: expected,
                                    evidence: [],
                                    suggestedActions: [CreativeOSActionCatalog.repairRun.actionRef])
    }
  }

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = "wub repair --anchors-pack-hint \(config.anchorsPackHint)" + (config.overwrite ? " --overwrite" : "")
    let cfg = CreativeOSActionCatalog.repairRunConfig(anchorsPackHint: config.anchorsPackHint,
                                                      overwrite: config.overwrite,
                                                      force: config.force,
                                                      yes: config.yes,
                                                      runsDir: config.runsDir)
    p.register(id: "repair_run") {
      [CreativeOS.PlanStep(id: "repair_run",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [
                             cfg,
                             CreativeOS.Effect(id: "repair_run", kind: .process, target: cmd, description: "Run repair recipe")
                           ],
                           idempotent: true,
                           manualReason: "repair_run_required",
                           actionRef: CreativeOSActionCatalog.repairRun.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
