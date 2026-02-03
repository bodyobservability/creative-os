import Foundation

struct CreativeOSActionCatalog {
  struct ActionSpec {
    let id: String
    let kind: CreativeOS.ActionRefKind
    let description: String
    let configKeys: [String]
    let requiresStationGate: Bool
    let enabledInStateSetup: Bool

    var actionRef: CreativeOS.ActionRef {
      CreativeOS.ActionRef(id: id, kind: kind, description: description)
    }
  }

  enum ConfigKey {
    static let abi = "abi"
    static let allowCgevent = "allow_cgevent"
    static let allowOcrFallback = "allow_ocr_fallback"
    static let anchorsPack = "anchors_pack"
    static let anchorsPackHint = "anchors_pack_hint"
    static let artifactIndex = "artifact_index"
    static let baseline = "baseline"
    static let currentSweep = "current_sweep"
    static let dryRun = "dry_run"
    static let fix = "fix"
    static let format = "format"
    static let force = "force"
    static let groupByFix = "group_by_fix"
    static let onlyFail = "only_fail"
    static let macro = "macro"
    static let macroOcr = "macro_ocr"
    static let macroRegion = "macro_region"
    static let manifest = "manifest"
    static let modalTest = "modal_test"
    static let nonInteractive = "non_interactive"
    static let noWriteReport = "no_write_report"
    static let out = "out"
    static let outDir = "out_dir"
    static let overwrite = "overwrite"
    static let postcheck = "postcheck"
    static let preflight = "preflight"
    static let profile = "profile"
    static let profilePath = "profile_path"
    static let rackId = "rack_id"
    static let rackManifest = "rack_manifest"
    static let rackVerifyManifest = "rack_verify_manifest"
    static let receiptIndex = "receipt_index"
    static let regions = "regions"
    static let regionsConfig = "regions_config"
    static let requiredControllers = "required_controllers"
    static let runApply = "run_apply"
    static let runDir = "run_dir"
    static let runsDir = "runs_dir"
    static let script = "script"
    static let serumOut = "serum_out"
    static let sessionProfile = "session_profile"
    static let sessionProfilePath = "session_profile_path"
    static let vrlMapping = "vrl_mapping"
    static let baysSpec = "bays_spec"
    static let racksOut = "racks_out"
    static let performanceOut = "performance_out"
    static let extrasSpec = "extras_spec"
    static let writeReport = "write_report"
    static let yes = "yes"
  }

  static let sweeperRun = ActionSpec(
    id: "sweeper.run",
    kind: .setup,
    description: "Run sweeper service",
    configKeys: [
      ConfigKey.anchorsPack,
      ConfigKey.modalTest,
      ConfigKey.requiredControllers,
      ConfigKey.allowOcrFallback,
      ConfigKey.fix,
      ConfigKey.regionsConfig,
      ConfigKey.runsDir
    ],
    requiresStationGate: false,
    enabledInStateSetup: true
  )

  static let readyCheck = ActionSpec(
    id: "ready.check",
    kind: .recheck,
    description: "Run ready service",
    configKeys: [
      ConfigKey.anchorsPackHint,
      ConfigKey.artifactIndex,
      ConfigKey.runDir,
      ConfigKey.writeReport
    ],
    requiresStationGate: false,
    enabledInStateSetup: true
  )

  static let driftCheck = ActionSpec(
    id: "drift.check",
    kind: .recheck,
    description: "Run drift check",
    configKeys: [
      ConfigKey.artifactIndex,
      ConfigKey.receiptIndex,
      ConfigKey.anchorsPackHint,
      ConfigKey.out,
      ConfigKey.format,
      ConfigKey.groupByFix,
      ConfigKey.onlyFail
    ],
    requiresStationGate: false,
    enabledInStateSetup: true
  )

  static let driftFix = ActionSpec(
    id: "drift.fix",
    kind: .repair,
    description: "Run drift fix service",
    configKeys: [
      ConfigKey.force,
      ConfigKey.artifactIndex,
      ConfigKey.receiptIndex,
      ConfigKey.anchorsPackHint,
      ConfigKey.yes,
      ConfigKey.dryRun,
      ConfigKey.out,
      ConfigKey.runsDir
    ],
    requiresStationGate: true,
    enabledInStateSetup: true
  )

  static let assetsExportAll = ActionSpec(
    id: "assets.export_all",
    kind: .setup,
    description: "Run assets export-all service",
    configKeys: [
      ConfigKey.anchorsPack,
      ConfigKey.overwrite,
      ConfigKey.nonInteractive,
      ConfigKey.preflight,
      ConfigKey.runsDir,
      ConfigKey.regionsConfig,
      ConfigKey.racksOut,
      ConfigKey.performanceOut,
      ConfigKey.baysSpec,
      ConfigKey.serumOut,
      ConfigKey.extrasSpec,
      ConfigKey.postcheck,
      ConfigKey.rackVerifyManifest,
      ConfigKey.vrlMapping,
      ConfigKey.force
    ],
    requiresStationGate: true,
    enabledInStateSetup: true
  )

  static let voiceRun = ActionSpec(
    id: "voice.run",
    kind: .setup,
    description: "Run voice handshake service",
    configKeys: [
      ConfigKey.script,
      ConfigKey.abi,
      ConfigKey.anchorsPack,
      ConfigKey.regions,
      ConfigKey.macroOcr,
      ConfigKey.macroRegion,
      ConfigKey.fix,
      ConfigKey.runsDir,
      ConfigKey.sessionProfile,
      ConfigKey.sessionProfilePath
    ],
    requiresStationGate: true,
    enabledInStateSetup: true
  )

  static let rackInstall = ActionSpec(
    id: "rack.install",
    kind: .setup,
    description: "Run rack install service",
    configKeys: [
      ConfigKey.anchorsPack,
      ConfigKey.manifest,
      ConfigKey.macroRegion,
      ConfigKey.allowCgevent,
      ConfigKey.runsDir,
      ConfigKey.sessionProfile,
      ConfigKey.sessionProfilePath
    ],
    requiresStationGate: true,
    enabledInStateSetup: true
  )

  static let rackVerify = ActionSpec(
    id: "rack.verify",
    kind: .setup,
    description: "Run rack verify service",
    configKeys: [
      ConfigKey.anchorsPack,
      ConfigKey.manifest,
      ConfigKey.macroRegion,
      ConfigKey.runApply,
      ConfigKey.runsDir,
      ConfigKey.sessionProfile,
      ConfigKey.sessionProfilePath
    ],
    requiresStationGate: true,
    enabledInStateSetup: true
  )

  static let sessionCompile = ActionSpec(
    id: "session.compile",
    kind: .setup,
    description: "Run session compile service",
    configKeys: [
      ConfigKey.profile,
      ConfigKey.profilePath,
      ConfigKey.anchorsPack,
      ConfigKey.fix,
      ConfigKey.runsDir
    ],
    requiresStationGate: true,
    enabledInStateSetup: true
  )

  static let indexBuild = ActionSpec(
    id: "index.build",
    kind: .setup,
    description: "Run index build service",
    configKeys: [
      ConfigKey.repoVersion,
      ConfigKey.outDir,
      ConfigKey.runsDir
    ],
    requiresStationGate: false,
    enabledInStateSetup: true
  )

  static let releasePromoteProfile = ActionSpec(
    id: "release.promote_profile",
    kind: .setup,
    description: "Run release promote service",
    configKeys: [
      ConfigKey.profile,
      ConfigKey.rackId,
      ConfigKey.macro,
      ConfigKey.baseline,
      ConfigKey.currentSweep,
      ConfigKey.out,
      ConfigKey.rackManifest,
      ConfigKey.runsDir
    ],
    requiresStationGate: true,
    enabledInStateSetup: true
  )

  static let reportGenerate = ActionSpec(
    id: "report.generate",
    kind: .setup,
    description: "Run report generation service",
    configKeys: [
      ConfigKey.runDir,
      ConfigKey.out
    ],
    requiresStationGate: false,
    enabledInStateSetup: true
  )

  static let repairRun = ActionSpec(
    id: "repair.run",
    kind: .setup,
    description: "Run repair service",
    configKeys: [
      ConfigKey.force,
      ConfigKey.anchorsPackHint,
      ConfigKey.yes,
      ConfigKey.overwrite,
      ConfigKey.runsDir
    ],
    requiresStationGate: true,
    enabledInStateSetup: true
  )

  static let stationStatus = ActionSpec(
    id: "station.status",
    kind: .recheck,
    description: "Run station status service",
    configKeys: [
      ConfigKey.format,
      ConfigKey.out,
      ConfigKey.noWriteReport,
      ConfigKey.anchorsPackHint,
      ConfigKey.runsDir
    ],
    requiresStationGate: false,
    enabledInStateSetup: true
  )

  static let all: [ActionSpec] = [
    sweeperRun,
    readyCheck,
    driftCheck,
    driftFix,
    assetsExportAll,
    voiceRun,
    rackInstall,
    rackVerify,
    sessionCompile,
    indexBuild,
    releasePromoteProfile,
    reportGenerate,
    repairRun,
    stationStatus
  ]

  static func spec(for id: String) -> ActionSpec? {
    all.first { $0.id == id }
  }

  static var stateSetupAllowlist: Set<String> {
    Set(all.filter { $0.enabledInStateSetup }.map { $0.id })
  }

  static func sweeperConfig(anchorsPack: String?,
                            modalTest: String,
                            requiredControllers: [String],
                            allowOcrFallback: Bool,
                            fix: Bool,
                            regionsConfig: String? = nil,
                            runsDir: String? = nil) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.anchorsPack, anchorsPack),
      (ConfigKey.modalTest, modalTest),
      (ConfigKey.requiredControllers, requiredControllers),
      (ConfigKey.allowOcrFallback, allowOcrFallback),
      (ConfigKey.fix, fix),
      (ConfigKey.regionsConfig, regionsConfig),
      (ConfigKey.runsDir, runsDir)
    ])
    return configEffect(id: "sweeper_config", payload: payload)
  }

  static func driftCheckConfig(anchorsPackHint: String?,
                               artifactIndex: String,
                               receiptIndex: String,
                               groupByFix: Bool? = nil,
                               onlyFail: Bool? = nil,
                               format: String? = nil,
                               out: String? = nil) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.anchorsPackHint, anchorsPackHint),
      (ConfigKey.artifactIndex, artifactIndex),
      (ConfigKey.receiptIndex, receiptIndex),
      (ConfigKey.groupByFix, groupByFix),
      (ConfigKey.onlyFail, onlyFail),
      (ConfigKey.format, format),
      (ConfigKey.out, out)
    ])
    return configEffect(id: "drift_config", payload: payload)
  }

  static func driftFixConfig(anchorsPackHint: String?,
                             artifactIndex: String,
                             receiptIndex: String,
                             dryRun: Bool,
                             force: Bool = false,
                             yes: Bool = false,
                             out: String? = nil,
                             runsDir: String? = nil) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.anchorsPackHint, anchorsPackHint),
      (ConfigKey.artifactIndex, artifactIndex),
      (ConfigKey.receiptIndex, receiptIndex),
      (ConfigKey.dryRun, dryRun),
      (ConfigKey.force, force),
      (ConfigKey.yes, yes),
      (ConfigKey.out, out),
      (ConfigKey.runsDir, runsDir)
    ])
    return configEffect(id: "drift_config", payload: payload)
  }

  static func readyCheckConfig(anchorsPackHint: String,
                               artifactIndex: String? = nil,
                               runDir: String? = nil,
                               writeReport: Bool? = nil) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.anchorsPackHint, anchorsPackHint),
      (ConfigKey.artifactIndex, artifactIndex),
      (ConfigKey.runDir, runDir),
      (ConfigKey.writeReport, writeReport)
    ])
    return configEffect(id: "ready_config", payload: payload)
  }

  static func stationStatusConfig(format: String,
                                  noWriteReport: Bool,
                                  anchorsPackHint: String,
                                  out: String? = nil,
                                  runsDir: String? = nil) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.format, format),
      (ConfigKey.noWriteReport, noWriteReport),
      (ConfigKey.anchorsPackHint, anchorsPackHint),
      (ConfigKey.out, out),
      (ConfigKey.runsDir, runsDir)
    ])
    return configEffect(id: "station_config", payload: payload)
  }

  static func assetsExportAllConfig(anchorsPack: String?,
                                    overwrite: Bool,
                                    nonInteractive: Bool,
                                    preflight: Bool,
                                    runsDir: String? = nil,
                                    regionsConfig: String? = nil,
                                    racksOut: String? = nil,
                                    performanceOut: String? = nil,
                                    baysSpec: String? = nil,
                                    serumOut: String? = nil,
                                    extrasSpec: String? = nil,
                                    postcheck: Bool? = nil,
                                    rackVerifyManifest: String? = nil,
                                    vrlMapping: String? = nil,
                                    force: Bool? = nil) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.anchorsPack, anchorsPack),
      (ConfigKey.overwrite, overwrite),
      (ConfigKey.nonInteractive, nonInteractive),
      (ConfigKey.preflight, preflight),
      (ConfigKey.runsDir, runsDir),
      (ConfigKey.regionsConfig, regionsConfig),
      (ConfigKey.racksOut, racksOut),
      (ConfigKey.performanceOut, performanceOut),
      (ConfigKey.baysSpec, baysSpec),
      (ConfigKey.serumOut, serumOut),
      (ConfigKey.extrasSpec, extrasSpec),
      (ConfigKey.postcheck, postcheck),
      (ConfigKey.rackVerifyManifest, rackVerifyManifest),
      (ConfigKey.vrlMapping, vrlMapping),
      (ConfigKey.force, force)
    ])
    return configEffect(id: "assets_config", payload: payload)
  }

  static func voiceRackSessionConfig(sessionProfile: String,
                                     sessionProfilePath: String,
                                     anchorsPack: String?,
                                     macroRegion: String,
                                     allowCgevent: Bool,
                                     fix: Bool) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.sessionProfile, sessionProfile),
      (ConfigKey.sessionProfilePath, sessionProfilePath),
      (ConfigKey.anchorsPack, anchorsPack),
      (ConfigKey.macroRegion, macroRegion),
      (ConfigKey.allowCgevent, allowCgevent),
      (ConfigKey.fix, fix)
    ])
    return configEffect(id: "voice_rack_session_config", payload: payload)
  }

  static func voiceRunConfig(config: VoiceService.RunConfig) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.script, config.script),
      (ConfigKey.abi, config.abi),
      (ConfigKey.anchorsPack, config.anchorsPack),
      (ConfigKey.regions, config.regions),
      (ConfigKey.macroOcr, config.macroOcr),
      (ConfigKey.macroRegion, config.macroRegion),
      (ConfigKey.fix, config.fix),
      (ConfigKey.runsDir, config.runsDir)
    ])
    return configEffect(id: "voice_config", payload: payload)
  }

  static func rackInstallConfig(config: RackInstallService.Config) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.manifest, config.manifest),
      (ConfigKey.macroRegion, config.macroRegion),
      (ConfigKey.anchorsPack, config.anchorsPack),
      (ConfigKey.allowCgevent, config.allowCgevent),
      (ConfigKey.runsDir, config.runsDir)
    ])
    return configEffect(id: "rack_install_config", payload: payload)
  }

  static func rackVerifyConfig(config: RackVerifyService.Config) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.manifest, config.manifest),
      (ConfigKey.macroRegion, config.macroRegion),
      (ConfigKey.runApply, config.runApply),
      (ConfigKey.anchorsPack, config.anchorsPack),
      (ConfigKey.runsDir, config.runsDir)
    ])
    return configEffect(id: "rack_verify_config", payload: payload)
  }

  static func sessionCompileConfig(profile: String,
                                   profilePath: String? = nil,
                                   anchorsPack: String?,
                                   fix: Bool) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.profile, profile),
      (ConfigKey.profilePath, profilePath),
      (ConfigKey.anchorsPack, anchorsPack),
      (ConfigKey.fix, fix)
    ])
    return configEffect(id: "session_config", payload: payload)
  }

  static func indexBuildConfig(repoVersion: String,
                               outDir: String,
                               runsDir: String) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.repoVersion, repoVersion),
      (ConfigKey.outDir, outDir),
      (ConfigKey.runsDir, runsDir)
    ])
    return configEffect(id: "index_config", payload: payload)
  }

  static func releasePromoteProfileConfig(profile: String,
                                          rackId: String,
                                          macro: String,
                                          baseline: String,
                                          currentSweep: String,
                                          out: String? = nil,
                                          rackManifest: String? = nil,
                                          runsDir: String? = nil) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.profile, profile),
      (ConfigKey.rackId, rackId),
      (ConfigKey.macro, macro),
      (ConfigKey.baseline, baseline),
      (ConfigKey.currentSweep, currentSweep),
      (ConfigKey.out, out),
      (ConfigKey.rackManifest, rackManifest),
      (ConfigKey.runsDir, runsDir)
    ])
    return configEffect(id: "release_config", payload: payload)
  }

  static func reportGenerateConfig(runDir: String, out: String? = nil) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.runDir, runDir),
      (ConfigKey.out, out)
    ])
    return configEffect(id: "report_config", payload: payload)
  }

  static func repairRunConfig(anchorsPackHint: String,
                              overwrite: Bool,
                              force: Bool = false,
                              yes: Bool = false,
                              runsDir: String? = nil) -> CreativeOS.Effect {
    let payload = configPayload([
      (ConfigKey.anchorsPackHint, anchorsPackHint),
      (ConfigKey.overwrite, overwrite),
      (ConfigKey.force, force),
      (ConfigKey.yes, yes),
      (ConfigKey.runsDir, runsDir)
    ])
    return configEffect(id: "repair_config", payload: payload)
  }

  private static func configPayload(_ entries: [(String, Any?)]) -> [String: Any] {
    var payload: [String: Any] = [:]
    for (key, value) in entries {
      if let value { payload[key] = value }
    }
    return payload
  }

  private static func configEffect(id: String, payload: [String: Any]) -> CreativeOS.Effect {
    let data = (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])) ?? Data()
    let json = String(data: data, encoding: .utf8) ?? "{}"
    return CreativeOS.Effect(id: id, kind: .config, target: json, description: "service_config")
  }
}

private extension CreativeOSActionCatalog.ConfigKey {
  static let repoVersion = "repo_version"
}
