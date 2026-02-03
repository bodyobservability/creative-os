import Foundation
import ArgumentParser

struct ServiceExecutor {
  private static let handlers: ActionHandlerRegistry = {
    var registry = ActionHandlerRegistry()
    registry.register(ActionHandler(id: "sweeper.run") { bag, _ in
      let config = SweeperService.Config(anchorsPack: bag.string("anchors_pack"),
                                         modalTest: bag.string("modal_test") ?? "detect",
                                         requiredControllers: bag.stringArray("required_controllers"),
                                         allowOcrFallback: bag.bool("allow_ocr_fallback") ?? false,
                                         fix: bag.bool("fix") ?? false,
                                         regionsConfig: bag.string("regions_config") ?? "tools/automation/swift-cli/config/regions.v1.json",
                                         runsDir: bag.string("runs_dir") ?? "runs")
      _ = try await SweeperService.run(config: config)
      return 0
    })
    registry.register(ActionHandler(id: "ready.check") { bag, _ in
      let hint = bag.string("anchors_pack_hint") ?? "specs/automation/anchors/<pack_id>"
      let config = ReadyService.Config(anchorsPackHint: hint,
                                       artifactIndex: bag.string("artifact_index") ?? "checksums/index/artifact_index.v1.json",
                                       runDir: bag.string("run_dir"),
                                       writeReport: bag.bool("write_report") ?? true)
      _ = try ReadyService.run(config: config)
      return 0
    })
    registry.register(ActionHandler(id: "drift.check") { bag, _ in
      let config = DriftService.Config(artifactIndex: bag.string("artifact_index") ?? "checksums/index/artifact_index.v1.json",
                                       receiptIndex: bag.string("receipt_index") ?? "checksums/index/receipt_index.v1.json",
                                       anchorsPackHint: bag.string("anchors_pack_hint"),
                                       out: nil,
                                       format: "human",
                                       groupByFix: true,
                                       onlyFail: false)
      _ = try DriftService.check(config: config)
      return 0
    })
    registry.register(ActionHandler(id: "drift.fix") { bag, _ in
      let config = DriftFixService.Config(force: bag.bool("force") ?? false,
                                          artifactIndex: bag.string("artifact_index") ?? "checksums/index/artifact_index.v1.json",
                                          receiptIndex: bag.string("receipt_index") ?? "checksums/index/receipt_index.v1.json",
                                          anchorsPackHint: bag.string("anchors_pack_hint") ?? "specs/automation/anchors/<pack_id>",
                                          yes: bag.bool("yes") ?? false,
                                          dryRun: bag.bool("dry_run") ?? false,
                                          out: nil,
                                          runsDir: bag.string("runs_dir") ?? "runs")
      let receipt = try await DriftFixService.run(config: config)
      return receipt.status == "fail" ? 1 : 0
    })
    registry.register(ActionHandler(id: "assets.export_all") { bag, _ in
      let config = AssetsService.ExportAllConfig(anchorsPack: bag.string("anchors_pack"),
                                                 overwrite: bag.bool("overwrite") ?? false,
                                                 nonInteractive: bag.bool("non_interactive") ?? false,
                                                 preflight: bag.bool("preflight") ?? true,
                                                 runsDir: bag.string("runs_dir") ?? "runs",
                                                 regionsConfig: bag.string("regions_config") ?? "tools/automation/swift-cli/config/regions.v1.json",
                                                 racksOut: bag.string("racks_out") ?? WubDefaults.packPath("ableton/racks/BASS_RACKS_v1.0"),
                                                 performanceOut: bag.string("performance_out") ?? WubDefaults.packPath("ableton/performance-sets/BASS_PERFORMANCE_SET_v1.0.als"),
                                                 baysSpec: bag.string("bays_spec") ?? WubDefaults.profileSpecPath("assets/export/finishing_bays_export.v1.yaml"),
                                                 serumOut: bag.string("serum_out") ?? "library/serum/SERUM_BASE_v1.0.fxp",
                                                 extrasSpec: bag.string("extras_spec") ?? WubDefaults.profileSpecPath("assets/export/extra_exports.v1.yaml"),
                                                 postcheck: bag.bool("postcheck") ?? true,
                                                 rackVerifyManifest: bag.string("rack_verify_manifest") ?? WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json"),
                                                 vrlMapping: bag.string("vrl_mapping") ?? WubDefaults.profileSpecPath("voice_runtime/v9_3_ableton_mapping.v1.yaml"),
                                                 force: bag.bool("force") ?? false)
      let receipt = try await AssetsService.exportAll(config: config)
      return receipt.status == "fail" ? 1 : 0
    })
    registry.register(ActionHandler(id: "voice.run") { bag, _ in
      var script = bag.string("script")
      var abi = bag.string("abi")
      var anchorsPack = bag.stringNonEmpty("anchors_pack")
      var regions = bag.string("regions")
      var macroOcr = bag.bool("macro_ocr")
      var macroRegion = bag.string("macro_region")
      if let sessionProfile = try loadSessionProfile(from: bag) {
        script = script ?? sessionProfile.voiceScript
        abi = abi ?? sessionProfile.voiceAbi
        anchorsPack = anchorsPack ?? sessionProfile.anchorsPack
        regions = regions ?? sessionProfile.regionsPath
        macroOcr = macroOcr ?? sessionProfile.voiceMacroOCR
        macroRegion = macroRegion ?? sessionProfile.voiceMacroRegion
      }
      guard let script, let abi, let anchorsPack, let regions else {
        throw ExecutionError.missingConfig
      }
      let config = VoiceService.RunConfig(script: script,
                                          abi: abi,
                                          anchorsPack: anchorsPack,
                                          regions: regions,
                                          macroOcr: macroOcr ?? true,
                                          macroRegion: macroRegion ?? "rack.macros",
                                          fix: bag.bool("fix") ?? false,
                                          runsDir: bag.string("runs_dir") ?? "runs")
      let receipt = try await VoiceService.run(config: config)
      return receipt.status == "fail" ? 1 : 0
    })
    registry.register(ActionHandler(id: "rack.install") { bag, _ in
      var manifest = bag.string("manifest")
      var macroRegion = bag.string("macro_region")
      var anchorsPack = bag.stringNonEmpty("anchors_pack")
      if let sessionProfile = try loadSessionProfile(from: bag) {
        manifest = manifest ?? sessionProfile.rackManifest
        macroRegion = macroRegion ?? sessionProfile.rackMacroRegion
        anchorsPack = anchorsPack ?? sessionProfile.anchorsPack
      }
      guard let manifest else { throw ExecutionError.missingConfig }
      let config = RackInstallService.Config(manifest: manifest,
                                             macroRegion: macroRegion ?? "rack.macros",
                                             anchorsPack: anchorsPack,
                                             allowCgevent: bag.bool("allow_cgevent") ?? false,
                                             runsDir: bag.string("runs_dir") ?? "runs")
      let receipt = try await RackInstallService.install(config: config)
      return receipt.status == "fail" ? 1 : 0
    })
    registry.register(ActionHandler(id: "rack.verify") { bag, _ in
      var manifest = bag.string("manifest")
      var macroRegion = bag.string("macro_region")
      var anchorsPack = bag.stringNonEmpty("anchors_pack")
      if let sessionProfile = try loadSessionProfile(from: bag) {
        manifest = manifest ?? sessionProfile.rackManifest
        macroRegion = macroRegion ?? sessionProfile.rackMacroRegion
        anchorsPack = anchorsPack ?? sessionProfile.anchorsPack
      }
      guard let manifest else { throw ExecutionError.missingConfig }
      let config = RackVerifyService.Config(manifest: manifest,
                                            macroRegion: macroRegion ?? "rack.macros",
                                            runApply: bag.bool("run_apply") ?? true,
                                            anchorsPack: anchorsPack,
                                            runsDir: bag.string("runs_dir") ?? "runs")
      let receipt = try await RackVerifyService.verify(config: config)
      return receipt.status == "fail" ? 1 : 0
    })
    registry.register(ActionHandler(id: "session.compile") { bag, _ in
      guard let profile = bag.string("profile") else { throw ExecutionError.missingConfig }
      let config = SessionService.Config(profile: profile,
                                         profilePath: bag.string("profile_path"),
                                         anchorsPack: bag.string("anchors_pack"),
                                         fix: bag.bool("fix") ?? false,
                                         runsDir: bag.string("runs_dir") ?? "runs")
      let receipt = try await SessionService.compile(config: config)
      return receipt.status == "fail" ? 1 : 0
    })
    registry.register(ActionHandler(id: "index.build") { bag, _ in
      let config = IndexService.BuildConfig(repoVersion: bag.string("repo_version") ?? "v1.8.4",
                                            outDir: bag.string("out_dir") ?? "checksums/index",
                                            runsDir: bag.string("runs_dir") ?? "runs")
      _ = try IndexService.build(config: config)
      return 0
    })
    registry.register(ActionHandler(id: "release.promote_profile") { bag, _ in
      guard let profile = bag.string("profile"),
            let rackId = bag.string("rack_id"),
            let macro = bag.string("macro"),
            let baseline = bag.string("baseline"),
            let currentSweep = bag.string("current_sweep") else { throw ExecutionError.missingConfig }
      let config = ReleaseService.PromoteConfig(profile: profile,
                                                out: bag.string("out"),
                                                rackId: rackId,
                                                macro: macro,
                                                baseline: baseline,
                                                currentSweep: currentSweep,
                                                rackManifest: bag.string("rack_manifest") ?? WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json"),
                                                runsDir: bag.string("runs_dir") ?? "runs")
      let receipt = try await ReleaseService.promoteProfile(config: config)
      return receipt.status == "fail" ? 1 : 0
    })
    registry.register(ActionHandler(id: "report.generate") { bag, _ in
      guard let runDir = bag.string("run_dir") else { throw ExecutionError.missingConfig }
      _ = try ReportService.generate(config: .init(runDir: runDir, out: bag.string("out")))
      return 0
    })
    registry.register(ActionHandler(id: "repair.run") { bag, _ in
      let config = RepairService.Config(force: bag.bool("force") ?? false,
                                        anchorsPackHint: bag.string("anchors_pack_hint") ?? "specs/automation/anchors/<pack_id>",
                                        yes: bag.bool("yes") ?? false,
                                        overwrite: bag.bool("overwrite") ?? true,
                                        runsDir: bag.string("runs_dir") ?? "runs")
      let receipt = try await RepairService.run(config: config)
      if let receipt, receipt.status == "fail" { return 1 }
      return 0
    })
    registry.register(ActionHandler(id: "station.status") { bag, _ in
      let config = StationStatusService.Config(format: bag.string("format") ?? "human",
                                               out: bag.string("out"),
                                               noWriteReport: bag.bool("no_write_report") ?? false,
                                               anchorsPackHint: bag.string("anchors_pack_hint") ?? "specs/automation/anchors/<pack_id>",
                                               runsDir: bag.string("runs_dir") ?? "runs")
      _ = try await StationStatusService.run(config: config)
      return 0
    })
    return registry
  }()

  static let supportedActionIds: Set<String> = handlers.ids

  static func supports(actionId: String) -> Bool {
    supportedActionIds.contains(actionId)
  }

  struct ConfigBag {
    let raw: [String: Any]

    func string(_ key: String) -> String? { raw[key] as? String }
    func stringNonEmpty(_ key: String) -> String? {
      guard let val = raw[key] as? String, !val.isEmpty else { return nil }
      return val
    }
    func bool(_ key: String) -> Bool? { raw[key] as? Bool }
    func int(_ key: String) -> Int? { raw[key] as? Int }
    func double(_ key: String) -> Double? { raw[key] as? Double }
    func stringArray(_ key: String) -> [String] { raw[key] as? [String] ?? [] }
  }

  enum ExecutionError: Error { case missingConfig, unsupportedAction(String) }

  static func execute(step: CreativeOS.PlanStep) async throws -> Int32? {
    guard let action = step.actionRef else { return nil }
    let bag = try loadConfig(from: step)
    guard let handler = handlers.handler(for: action.id) else {
      throw ExecutionError.unsupportedAction(action.id)
    }
    return try await handler.execute(bag, step)
  }

  private static func loadConfig(from step: CreativeOS.PlanStep) throws -> ConfigBag {
    guard let configEffect = step.effects.first(where: { $0.kind == .config }) else {
      throw ExecutionError.missingConfig
    }
    guard let data = configEffect.target.data(using: .utf8),
          let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw ExecutionError.missingConfig
    }
    return ConfigBag(raw: obj)
  }

  private static func loadSessionProfile(from bag: ConfigBag) throws -> SessionService.SessionProfileConfig? {
    guard let profileId = bag.string("session_profile") ?? bag.string("profile") else { return nil }
    let profilePath = bag.string("session_profile_path")
    return try SessionService.loadProfileConfig(profile: profileId, profilePath: profilePath)
  }
}
