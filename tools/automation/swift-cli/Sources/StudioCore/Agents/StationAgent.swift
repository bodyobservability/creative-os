import Foundation

struct StationAgent: CreativeOS.Agent {
  let id: String = "station"
  let config: StationStatusService.Config

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
    r.register(id: "station_inputs") {
      let anchorsOk = FileManager.default.fileExists(atPath: config.anchorsPackHint)
      let observed: CreativeOS.JSONValue = .object([
        "anchors_pack_exists": .bool(anchorsOk)
      ])
      let expected: CreativeOS.JSONValue = .object([
        "anchors_pack_exists": .bool(true)
      ])
      return CreativeOS.CheckResult(id: "station_inputs",
                                    agent: id,
                                    severity: anchorsOk ? .pass : .warn,
                                    category: .filesystem,
                                    observed: observed,
                                    expected: expected,
                                    evidence: [],
                                    suggestedActions: [CreativeOSActionCatalog.stationStatus.actionRef])
    }
  }

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = "wub station status --format \(config.format)" + (config.noWriteReport ? " --no-write-report" : "")
    let cfg = CreativeOSActionCatalog.stationStatusConfig(format: config.format,
                                                          noWriteReport: config.noWriteReport,
                                                          anchorsPackHint: config.anchorsPackHint,
                                                          out: config.out,
                                                          runsDir: config.runsDir)
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
