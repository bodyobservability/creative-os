import Foundation

struct StationAgent: CreativeOS.Agent {
  let id: String = "station"
  let config: StationConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = "wub station status --format \(config.format)" + (config.noWriteReport ? " --no-write-report" : "")
    let cfg = CreativeOSActionCatalog.stationStatusConfig(format: config.format,
                                                          noWriteReport: config.noWriteReport,
                                                          anchorsPackHint: "specs/automation/anchors/<pack_id>")
    p.register(id: "station_status") {
      [CreativeOS.PlanStep(id: "station_status",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [cfg, CreativeOS.Effect(id: "station_status", kind: .process, target: cmd, description: "Check station status")],
                           idempotent: true,
                           manualReason: "station_status",
                           actionRef: CreativeOSActionCatalog.stationStatus.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
