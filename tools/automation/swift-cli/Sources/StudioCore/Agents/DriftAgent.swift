import Foundation

struct DriftAgent: CreativeOS.Agent {
  let id: String = "drift"
  let checkConfig: DriftService.Config
  let fixConfig: DriftFixService.Config

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let hint = checkConfig.anchorsPackHint ?? ""
    let checkCmd = hint.isEmpty ? "wub drift check" : "wub drift check --anchors-pack-hint \(hint)"
    let planCmd = hint.isEmpty ? "wub drift plan" : "wub drift plan --anchors-pack-hint \(hint)"
    let fixCmd = hint.isEmpty ? "wub drift fix --dry-run" : "wub drift fix --anchors-pack-hint \(hint) --dry-run"
    let cfg = CreativeOSActionCatalog.driftCheckConfig(anchorsPackHint: checkConfig.anchorsPackHint,
                                                       artifactIndex: checkConfig.artifactIndex,
                                                       receiptIndex: checkConfig.receiptIndex,
                                                       groupByFix: checkConfig.groupByFix,
                                                       onlyFail: checkConfig.onlyFail,
                                                       format: checkConfig.format,
                                                       out: checkConfig.out)
    let fixCfg = CreativeOSActionCatalog.driftFixConfig(anchorsPackHint: fixConfig.anchorsPackHint,
                                                        artifactIndex: fixConfig.artifactIndex,
                                                        receiptIndex: fixConfig.receiptIndex,
                                                        dryRun: fixConfig.dryRun,
                                                        force: fixConfig.force,
                                                        yes: fixConfig.yes,
                                                        out: fixConfig.out,
                                                        runsDir: fixConfig.runsDir)

    p.register(id: "drift_check") {
      [CreativeOS.PlanStep(id: "drift_check",
                           agent: id,
                           type: .automated,
                           description: "Run: \(checkCmd)",
                           effects: [cfg, CreativeOS.Effect(id: "drift_check", kind: .process, target: checkCmd, description: "Run drift check")],
                           idempotent: true,
                           manualReason: "drift_check_required",
                           actionRef: CreativeOSActionCatalog.driftCheck.actionRef)]
    }
    p.register(id: "drift_plan") {
      [CreativeOS.PlanStep(id: "drift_plan",
                           agent: id,
                           type: .manualRequired,
                           description: "Run: \(planCmd)",
                           effects: [CreativeOS.Effect(id: "drift_plan", kind: .process, target: planCmd, description: "Run drift plan")],
                           idempotent: true,
                           manualReason: "drift_plan_required")]
    }
    p.register(id: "drift_fix") {
      [CreativeOS.PlanStep(id: "drift_fix",
                           agent: id,
                           type: .automated,
                           description: "Run: \(fixCmd)",
                           effects: [fixCfg, CreativeOS.Effect(id: "drift_fix", kind: .process, target: fixCmd, description: "Run drift fix (dry run)")],
                           idempotent: true,
                           manualReason: "drift_fix_required",
                           actionRef: CreativeOSActionCatalog.driftFix.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
