import Foundation

struct ProfileAgent: CreativeOS.Agent {
  let id: String = "profile"
  let profile: CreativeOS.Profile

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}
  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {}

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(profile.id),
      "intents": .array(profile.intents.map { .string($0) }),
      "policies": .object(profile.policies),
      "requirements": .object(profile.requirements),
      "packs": .array(profile.packs.map { .string($0) })
    ])
    return CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: json)
  }
}

struct PackAgent: CreativeOS.Agent {
  let pack: CreativeOS.PackManifest

  var id: String { "pack:\(pack.id)" }

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}
  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {}

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(pack.id),
      "applies_to": .array(pack.appliesTo.map { .string($0) }),
      "contents": .object(pack.contents),
      "requires_explicit_apply": .bool(pack.requiresExplicitApply)
    ])
    return CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: json)
  }

  func desiredState() throws -> CreativeOS.DesiredStateSlice? {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(pack.id),
      "applies_to": .array(pack.appliesTo.map { .string($0) }),
      "contents": .object(pack.contents),
      "requires_explicit_apply": .bool(pack.requiresExplicitApply)
    ])
    return CreativeOS.DesiredStateSlice(agentId: id, data: nil, raw: json)
  }
}

struct MappingAgent: CreativeOS.Agent {
  let id: String = "runtime"

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
    let issues = CreativeOSMapping.validate()
    guard !issues.isEmpty else { return }
    r.register(id: "migration_mapping_validation") {
      CreativeOS.CheckResult(id: "migration_mapping_validation",
                             agent: id,
                             severity: .warn,
                             category: .policy,
                             observed: .array(issues.map { .string($0) }),
                             expected: nil,
                             evidence: [
                               CreativeOS.EvidenceItem(id: "mapping_table", kind: "mapping", path: "docs/creative_os_mapping.md", details: nil)
                             ],
                             suggestedActions: [])
    }
  }

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let issues = CreativeOSMapping.validate()
    guard !issues.isEmpty else { return }
    p.register(id: "migration_mapping_validation") {
      [CreativeOS.PlanStep(id: "migration_mapping_validation",
                           agent: id,
                           type: .manualRequired,
                           description: "Resolve migration mapping validation issues",
                           effects: [],
                           idempotent: true,
                           manualReason: "mapping_validation")]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}

struct SweeperConfig {
  let anchorsPack: String?
  let modalTest: String
  let requiredControllers: [String]
  let allowOcrFallback: Bool
  let fix: Bool
}

struct DriftConfig {
  let anchorsPackHint: String?
}

struct ReadyConfig {
  let anchorsPackHint: String
}

struct StationConfig {
  let format: String
  let noWriteReport: Bool
}

struct AssetsConfig {
  let anchorsPack: String?
  let overwrite: Bool
  let nonInteractive: Bool
  let preflight: Bool
}

struct VoiceRackSessionConfig {
  let anchorsPack: String?
  let macroRegion: String
  let allowCgevent: Bool
  let fix: Bool
  let sessionProfile: String
}

struct IndexConfig {
  let repoVersion: String
  let outDir: String
  let runsDir: String
}

struct ReleaseConfig {
  let profilePath: String
  let rackId: String
  let macro: String
  let baseline: String
  let currentSweep: String
}

struct ReportConfig {
  let runDir: String
}

struct RepairConfig {
  let anchorsPackHint: String
  let overwrite: Bool
}

struct SweeperAgent: CreativeOS.Agent {
  let id: String = "sweeper"
  let config: SweeperConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = buildCommand()
    let cfg = CreativeOSActionCatalog.sweeperConfig(anchorsPack: config.anchorsPack,
                                                    modalTest: config.modalTest,
                                                    requiredControllers: config.requiredControllers,
                                                    allowOcrFallback: config.allowOcrFallback,
                                                    fix: config.fix)
    p.register(id: "sweep_maintenance") {
      [CreativeOS.PlanStep(id: "sweep_maintenance",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [
                             cfg,
                             CreativeOS.Effect(id: "sweep_command", kind: .process, target: cmd, description: "Run maintenance sweep")
                           ],
                           idempotent: true,
                           manualReason: "sweep_required",
                           actionRef: CreativeOSActionCatalog.sweeperRun.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }

  private func buildCommand() -> String {
    var args: [String] = ["wub", "sweep"]
    if let anchorsPack = config.anchorsPack, !anchorsPack.isEmpty {
      args += ["--anchors-pack", anchorsPack]
    }
    if !config.modalTest.isEmpty {
      args += ["--modal-test", config.modalTest]
    }
    if config.allowOcrFallback {
      args.append("--allow-ocr-fallback")
    }
    if config.fix {
      args.append("--fix")
    }
    for controller in config.requiredControllers {
      args += ["--require-controller", controller]
    }
    return args.joined(separator: " ")
  }
}

struct DriftAgent: CreativeOS.Agent {
  let id: String = "drift"
  let config: DriftConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let hint = config.anchorsPackHint ?? ""
    let checkCmd = hint.isEmpty ? "wub drift check" : "wub drift check --anchors-pack-hint \(hint)"
    let planCmd = hint.isEmpty ? "wub drift plan" : "wub drift plan --anchors-pack-hint \(hint)"
    let fixCmd = hint.isEmpty ? "wub drift fix --dry-run" : "wub drift fix --anchors-pack-hint \(hint) --dry-run"
    let cfg = CreativeOSActionCatalog.driftCheckConfig(anchorsPackHint: config.anchorsPackHint,
                                                       artifactIndex: "checksums/index/artifact_index.v1.json",
                                                       receiptIndex: "checksums/index/receipt_index.v1.json")
    let fixCfg = CreativeOSActionCatalog.driftFixConfig(anchorsPackHint: config.anchorsPackHint,
                                                        artifactIndex: "checksums/index/artifact_index.v1.json",
                                                        receiptIndex: "checksums/index/receipt_index.v1.json",
                                                        dryRun: true)

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

struct AssetsAgent: CreativeOS.Agent {
  let id: String = "assets"
  let config: AssetsConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = buildCommand()
    let cfg = CreativeOSActionCatalog.assetsExportAllConfig(anchorsPack: config.anchorsPack,
                                                           overwrite: config.overwrite,
                                                           nonInteractive: config.nonInteractive,
                                                           preflight: config.preflight)
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

struct VoiceRackSessionAgent: CreativeOS.Agent {
  let id: String = "voice_rack_session"
  let config: VoiceRackSessionConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let anchorsPack = config.anchorsPack.flatMap { $0.isEmpty ? nil : $0 }
    let anchorsFlag = anchorsPack ?? ""
    let apArgs = anchorsFlag.isEmpty ? "" : " --anchors-pack \(anchorsFlag)"
    let macroArgs = config.macroRegion.isEmpty ? "" : " --macro-region \(config.macroRegion)"
    let cgArg = config.allowCgevent ? " --allow-cgevent" : ""
    let fixArg = config.fix ? " --fix" : ""

    let voiceCmd = "wub voice run" + apArgs + macroArgs + fixArg
    let rackInstallCmd = "wub rack install" + apArgs + macroArgs + cgArg
    let rackVerifyCmd = "wub rack verify" + apArgs + macroArgs
    let sessionCmd = "wub session compile --profile \(config.sessionProfile)" + (anchorsFlag.isEmpty ? "" : " --anchors-pack \(anchorsFlag)")
    let vrsCfg = CreativeOSActionCatalog.voiceRackSessionConfig(sessionProfile: config.sessionProfile,
                                                                sessionProfilePath: WubDefaults.profileSpecPath("session/profiles/\(config.sessionProfile).yaml"),
                                                                anchorsPack: anchorsPack,
                                                                macroRegion: config.macroRegion,
                                                                allowCgevent: config.allowCgevent,
                                                                fix: config.fix)
    let sessionCfg = CreativeOSActionCatalog.sessionCompileConfig(profile: config.sessionProfile,
                                                                  anchorsPack: anchorsPack,
                                                                  fix: config.fix)

    p.register(id: "voice_run") {
      [CreativeOS.PlanStep(id: "voice_run",
                           agent: id,
                           type: .automated,
                           description: "Run: \(voiceCmd)",
                           effects: [
                             vrsCfg,
                             CreativeOS.Effect(id: "voice_run", kind: .process, target: voiceCmd, description: "Run voice handshake")
                           ],
                           idempotent: true,
                           manualReason: "voice_run_required",
                           actionRef: CreativeOSActionCatalog.voiceRun.actionRef)]
    }
    p.register(id: "rack_install") {
      [CreativeOS.PlanStep(id: "rack_install",
                           agent: id,
                           type: .automated,
                           description: "Run: \(rackInstallCmd)",
                           effects: [
                             vrsCfg,
                             CreativeOS.Effect(id: "rack_install", kind: .process, target: rackInstallCmd, description: "Install racks")
                           ],
                           idempotent: true,
                           manualReason: "rack_install_required",
                           actionRef: CreativeOSActionCatalog.rackInstall.actionRef)]
    }
    p.register(id: "rack_verify") {
      [CreativeOS.PlanStep(id: "rack_verify",
                           agent: id,
                           type: .automated,
                           description: "Run: \(rackVerifyCmd)",
                           effects: [
                             vrsCfg,
                             CreativeOS.Effect(id: "rack_verify", kind: .process, target: rackVerifyCmd, description: "Verify racks")
                           ],
                           idempotent: true,
                           manualReason: "rack_verify_required",
                           actionRef: CreativeOSActionCatalog.rackVerify.actionRef)]
    }
    p.register(id: "session_compile") {
      [CreativeOS.PlanStep(id: "session_compile",
                           agent: id,
                           type: .automated,
                           description: "Run: \(sessionCmd)",
                           effects: [sessionCfg, CreativeOS.Effect(id: "session_compile", kind: .process, target: sessionCmd, description: "Compile session")],
                           idempotent: true,
                           manualReason: "session_compile_required",
                           actionRef: CreativeOSActionCatalog.sessionCompile.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}

struct IndexAgent: CreativeOS.Agent {
  let id: String = "index"
  let config: IndexConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = "wub index build --repo-version \(config.repoVersion) --out-dir \(config.outDir) --runs-dir \(config.runsDir)"
    let cfg = CreativeOSActionCatalog.indexBuildConfig(repoVersion: config.repoVersion,
                                                       outDir: config.outDir,
                                                       runsDir: config.runsDir)
    p.register(id: "index_build") {
      [CreativeOS.PlanStep(id: "index_build",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [
                             cfg,
                             CreativeOS.Effect(id: "index_build", kind: .process, target: cmd, description: "Build indexes")
                           ],
                           idempotent: true,
                           manualReason: "index_build_required",
                           actionRef: CreativeOSActionCatalog.indexBuild.actionRef)]
    }
    p.register(id: "index_status") {
      let statusCmd = "wub index status"
      return [CreativeOS.PlanStep(id: "index_status",
                                  agent: id,
                                  type: .manualRequired,
                                  description: "Run: \(statusCmd)",
                                  effects: [CreativeOS.Effect(id: "index_status", kind: .process, target: statusCmd, description: "Check index status")],
                                  idempotent: true,
                                  manualReason: "index_status_required")]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}

struct ReleaseAgent: CreativeOS.Agent {
  let id: String = "release"
  let config: ReleaseConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = "wub release promote-profile --profile \(config.profilePath) --rack-id \(config.rackId) --macro \(config.macro) --baseline \(config.baseline) --current-sweep \(config.currentSweep)"
    let cfg = CreativeOSActionCatalog.releasePromoteProfileConfig(profile: config.profilePath,
                                                                  rackId: config.rackId,
                                                                  macro: config.macro,
                                                                  baseline: config.baseline,
                                                                  currentSweep: config.currentSweep)
    p.register(id: "release_promote_profile") {
      [CreativeOS.PlanStep(id: "release_promote_profile",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [
                             cfg,
                             CreativeOS.Effect(id: "release_promote_profile", kind: .process, target: cmd, description: "Promote profile")
                           ],
                           idempotent: true,
                           manualReason: "release_promote_required",
                           actionRef: CreativeOSActionCatalog.releasePromoteProfile.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}

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
