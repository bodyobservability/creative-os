import Foundation

struct ReadyAgent: CreativeOS.Agent {
  let id: String = "ready"
  let config: ReadyConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let hint = config.anchorsPackHint
    let cmd = "wub ready --anchors-pack-hint \(hint)"
    let cfg = CreativeOSActionCatalog.readyCheckConfig(anchorsPackHint: hint)
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
