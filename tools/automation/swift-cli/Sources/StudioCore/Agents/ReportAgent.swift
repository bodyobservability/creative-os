import Foundation

struct ReportAgent: CreativeOS.Agent {
  let id: String = "report"
  let config: ReportConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = "wub report generate --run-dir \(config.runDir)"
    let cfg = CreativeOSActionCatalog.reportGenerateConfig(runDir: config.runDir)
    p.register(id: "report_generate") {
      [CreativeOS.PlanStep(id: "report_generate",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [
                             cfg,
                             CreativeOS.Effect(id: "report_generate", kind: .process, target: cmd, description: "Generate run report")
                           ],
                           idempotent: true,
                           manualReason: "report_generate_required",
                           actionRef: CreativeOSActionCatalog.reportGenerate.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
