import Foundation

struct RepairAgent: CreativeOS.Agent {
  let id: String = "repair"
  let config: RepairConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = "wub repair --anchors-pack-hint \(config.anchorsPackHint)" + (config.overwrite ? " --overwrite" : "")
    let cfg = CreativeOSActionCatalog.repairRunConfig(anchorsPackHint: config.anchorsPackHint,
                                                      overwrite: config.overwrite)
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
