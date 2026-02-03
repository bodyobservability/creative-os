import Foundation

struct AssetsAgent: CreativeOS.Agent {
  let id: String = "assets"
  let config: AssetsService.ExportAllConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
    r.register(id: "assets_inputs") {
      var observed: [String: CreativeOS.JSONValue] = [
        "regions_config_exists": .bool(FileManager.default.fileExists(atPath: config.regionsConfig)),
        "rack_verify_manifest_exists": .bool(FileManager.default.fileExists(atPath: config.rackVerifyManifest))
      ]
      var expected: [String: CreativeOS.JSONValue] = [
        "regions_config_exists": .bool(true),
        "rack_verify_manifest_exists": .bool(true)
      ]
      if let anchorsPack = config.anchorsPack, !anchorsPack.isEmpty {
        let anchorsOk = FileManager.default.fileExists(atPath: anchorsPack)
        observed["anchors_pack_exists"] = .bool(anchorsOk)
        expected["anchors_pack_exists"] = .bool(true)
      }
      let ok = !observed.values.contains { value in
        if case .bool(false) = value { return true }
        return false
      }
      return CreativeOS.CheckResult(id: "assets_inputs",
                                    agent: id,
                                    severity: ok ? .pass : .warn,
                                    category: .filesystem,
                                    observed: .object(observed),
                                    expected: .object(expected),
                                    evidence: [],
                                    suggestedActions: [CreativeOSActionCatalog.assetsExportAll.actionRef])
    }
  }

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = buildCommand()
    let cfg = CreativeOSActionCatalog.assetsExportAllConfig(anchorsPack: config.anchorsPack,
                                                           overwrite: config.overwrite,
                                                           nonInteractive: config.nonInteractive,
                                                           preflight: config.preflight,
                                                           runsDir: config.runsDir,
                                                           regionsConfig: config.regionsConfig,
                                                           racksOut: config.racksOut,
                                                           performanceOut: config.performanceOut,
                                                           baysSpec: config.baysSpec,
                                                           serumOut: config.serumOut,
                                                           extrasSpec: config.extrasSpec,
                                                           postcheck: config.postcheck,
                                                           rackVerifyManifest: config.rackVerifyManifest,
                                                           vrlMapping: config.vrlMapping,
                                                           force: config.force)
    p.register(id: "assets_export_all") {
      [CreativeOS.PlanStep(id: "assets_export_all",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [cfg, CreativeOS.Effect(id: "assets_export_all", kind: .process, target: cmd, description: "Run assets export-all")],
                           idempotent: true,
                           manualReason: "assets_export_required",
                           actionRef: CreativeOSActionCatalog.assetsExportAll.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }

  private func buildCommand() -> String {
    var args: [String] = ["wub", "assets", "export-all"]
    if let anchorsPack = config.anchorsPack, !anchorsPack.isEmpty {
      args += ["--anchors-pack", anchorsPack]
    }
    if config.overwrite { args.append("--overwrite") }
    if config.nonInteractive { args.append("--non-interactive") }
    if !config.preflight { args.append("--no-preflight") }
    return args.joined(separator: " ")
  }
}
