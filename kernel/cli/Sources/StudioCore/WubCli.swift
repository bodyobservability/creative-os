import ArgumentParser
import Foundation

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct WubCli: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "wub",
    subcommands: [
      // Core
      A0.self,
      Resolve.self,
      Index.self,
      Drift.self,
      WubSweep.self,
      WubPlan.self,
      Apply.self,
      WubSetup.self,
      WubCheck.self,
      WubPreflight.self,

      // UI tooling
      CaptureAnchor.self,
      ValidateAnchors.self,
      CalibrateRegions.self,
      RegionsSelect.self,
      AnchorsSelect.self,

      // Safety + ops
      MidiList.self,

      // Voice + racks + sessions
      Voice.self,
      VRL.self,
      UI.self,
      OCRDumpCmd.self,
      Rack.self,
      Session.self,
      Assets.self,

      // Sonic + governance
      Sonic.self,
      Ready.self,
      Repair.self,
      Station.self,
      Release.self,
      Pipeline.self,
      Report.self,

      // Creative OS surfaces
      WubStateSweep.self,
      WubStatePlan.self,
      WubStateSetup.self,
      WubProfile.self,
      WubStation.self
    ]
  )
}

struct WubStateSweep: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "state-sweep")

  @Option(name: .long, help: "Run directory to inspect (default: latest in \(RepoPaths.defaultRunsDir())/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: \(RepoPaths.defaultRunsDir())).")
  var runsDir: String = RepoPaths.defaultRunsDir()

  @Flag(name: .long, help: "Output JSON.")
  var json: Bool = false

  func run() async throws {
    let context = WubContext(runDir: runDir,
                             runsDir: runsDir,
                             sweeperConfig: nil,
                             driftCheckConfig: nil,
                             driftFixConfig: nil,
                             readyConfig: nil,
                             stationConfig: nil,
                             assetsConfig: nil,
                             voiceConfig: nil,
                             rackInstallConfig: nil,
                             rackVerifyConfig: nil,
                             sessionConfig: nil,
                             indexConfig: nil,
                             releaseConfig: nil,
                             reportConfig: nil,
                             repairConfig: nil)
    let report = try context.makeSweepReport()
    try emit(report, json: json)
  }
}

struct WubSweep: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "sweep")

  @Option(name: .long, help: "Run directory to inspect (default: latest in \(RepoPaths.defaultRunsDir())/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: \(RepoPaths.defaultRunsDir())).")
  var runsDir: String = RepoPaths.defaultRunsDir()

  @Flag(name: .long, help: "Output JSON.")
  var json: Bool = false

  @Option(name: .long, help: "Anchors pack path for sweeper agent (optional).")
  var anchorsPack: String? = nil

  @Option(name: .long, help: "Modal test mode for sweeper agent: detect | active.")
  var modalTest: String = "detect"

  @Option(name: .long, parsing: .upToNextOption, help: "Required controllers for sweeper agent (repeatable).")
  var requireController: [String] = []

  @Flag(name: .long, help: "Allow OCR fallback for sweeper agent if OpenCV is not enabled.")
  var allowOcrFallback: Bool = false

  @Flag(name: .long, help: "Run sweeper agent with quick fix enabled.")
  var fix: Bool = false

  func run() async throws {
    let config = SweeperService.Config(anchorsPack: anchorsPack,
                                       modalTest: modalTest,
                                       requiredControllers: requireController,
                                       allowOcrFallback: allowOcrFallback,
                                       fix: fix,
                                       regionsConfig: RepoPaths.defaultRegionsConfigPath(),
                                       runsDir: runsDir)
    let context = WubContext(runDir: runDir,
                             runsDir: runsDir,
                             sweeperConfig: config,
                             driftCheckConfig: nil,
                             driftFixConfig: nil,
                             readyConfig: nil,
                             stationConfig: nil,
                             assetsConfig: nil,
                             voiceConfig: nil,
                             rackInstallConfig: nil,
                             rackVerifyConfig: nil,
                             sessionConfig: nil,
                             indexConfig: nil,
                             releaseConfig: nil,
                             reportConfig: nil,
                             repairConfig: nil)
    let report = try context.makeSweepReport()
    try emit(report, json: json)
  }
}

struct WubStatePlan: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "state-plan")

  @Option(name: .long, help: "Run directory to inspect (default: latest in \(RepoPaths.defaultRunsDir())/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: \(RepoPaths.defaultRunsDir())).")
  var runsDir: String = RepoPaths.defaultRunsDir()

  @Flag(name: .long, help: "Output JSON.")
  var json: Bool = false

  func run() async throws {
    let context = WubContext(runDir: runDir,
                             runsDir: runsDir,
                             sweeperConfig: nil,
                             driftCheckConfig: nil,
                             driftFixConfig: nil,
                             readyConfig: nil,
                             stationConfig: nil,
                             assetsConfig: nil,
                             voiceConfig: nil,
                             rackInstallConfig: nil,
                             rackVerifyConfig: nil,
                             sessionConfig: nil,
                             indexConfig: nil,
                             releaseConfig: nil,
                             reportConfig: nil,
                             repairConfig: nil)
    let report = try context.makePlanReport()
    try emit(report, json: json)
  }
}

struct WubPlan: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "plan")

  @Option(name: .long, help: "Run directory to inspect (default: latest in \(RepoPaths.defaultRunsDir())/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: \(RepoPaths.defaultRunsDir())).")
  var runsDir: String = RepoPaths.defaultRunsDir()

  @Flag(name: .long, help: "Output JSON.")
  var json: Bool = false

  @Option(name: .long, help: "Anchors pack path for sweeper agent (optional).")
  var anchorsPack: String? = nil

  @Option(name: .long, help: "Modal test mode for sweeper agent: detect | active.")
  var modalTest: String = "detect"

  @Option(name: .long, parsing: .upToNextOption, help: "Required controllers for sweeper agent (repeatable).")
  var requireController: [String] = []

  @Flag(name: .long, help: "Allow OCR fallback for sweeper agent if OpenCV is not enabled.")
  var allowOcrFallback: Bool = false

  @Flag(name: .long, help: "Run sweeper agent with quick fix enabled.")
  var fix: Bool = false

  @Option(name: .long, help: "Anchors pack hint for drift agent (optional).")
  var anchorsPackHint: String? = nil

  @Option(name: .long, help: "Anchors pack hint for ready agent.")
  var readyAnchorsPackHint: String = RepoPaths.defaultAnchorsPackHint()

  @Option(name: .long, help: "Station status format for station agent: human|json.")
  var stationStatusFormat: String = "json"

  @Flag(name: .long, help: "Station status without writing report.")
  var stationNoWriteReport: Bool = true

  @Option(name: .long, help: "Anchors pack for assets export-all agent.")
  var assetsAnchorsPack: String = RepoPaths.defaultAnchorsPackHint()

  @Flag(name: .long, help: "Assets export-all agent overwrite existing outputs.")
  var assetsOverwrite: Bool = false

  @Flag(name: .long, help: "Assets export-all agent non-interactive mode.")
  var assetsNonInteractive: Bool = false

  @Flag(name: .long, inversion: .prefixedNo, help: "Assets export-all agent preflight (default: enabled).")
  var assetsPreflight: Bool = true

  @Option(name: .long, help: "Anchors pack for voice/rack/session agent.")
  var vrsAnchorsPack: String? = nil

  @Option(name: .long, help: "Macro region for voice/rack/session agent.")
  var vrsMacroRegion: String = "rack.macros"

  @Flag(name: .long, help: "Allow CGEvent fallback for rack install.")
  var vrsAllowCgevent: Bool = false

  @Flag(name: .long, help: "Run voice handshake with fix enabled.")
  var vrsFix: Bool = false

  @Option(name: .long, help: "Session profile id for session compile.")
  var vrsSessionProfile: String = "bass_v1"

  @Option(name: .long, help: "Index build repo version.")
  var indexRepoVersion: String = "current"

  @Option(name: .long, help: "Index build output directory.")
  var indexOutDir: String = RepoPaths.defaultChecksumsIndexDir()

  @Option(name: .long, help: "Index build runs directory.")
  var indexRunsDir: String = RepoPaths.defaultRunsDir()

  @Option(name: .long, help: "Release candidate profile path.")
  var releaseProfilePath: String = RepoPaths.defaultReleaseProfilePath(profileId: "hvlien", relative: "library/profiles/dev/bass_lead.v1.yaml")

  @Option(name: .long, help: "Release rack id for certification.")
  var releaseRackId: String = "bass"

  @Option(name: .long, help: "Release macro for certification.")
  var releaseMacro: String = "Width"

  @Option(name: .long, help: "Release baseline receipt path.")
  var releaseBaseline: String = "\(RepoPaths.defaultRunsDir())/<run_id>/sonic_sweep_receipt.v1.json"

  @Option(name: .long, help: "Release current sweep receipt path.")
  var releaseCurrentSweep: String = "\(RepoPaths.defaultRunsDir())/<run_id>/sonic_sweep_receipt.v1.json"

  @Option(name: .long, help: "Report run directory for report generate.")
  var reportRunDir: String = "\(RepoPaths.defaultRunsDir())/<run_id>"

  @Option(name: .long, help: "Repair anchors pack hint.")
  var repairAnchorsPackHint: String = RepoPaths.defaultAnchorsPackHint()

  @Flag(name: .long, help: "Repair overwrite during export-all.")
  var repairOverwrite: Bool = true

  func run() async throws {
    let sweeperConfig = SweeperService.Config(anchorsPack: anchorsPack,
                                              modalTest: modalTest,
                                              requiredControllers: requireController,
                                              allowOcrFallback: allowOcrFallback,
                                              fix: fix,
                                              regionsConfig: RepoPaths.defaultRegionsConfigPath(),
                                              runsDir: runsDir)
    let driftCheckConfig = DriftService.Config(artifactIndex: RepoPaths.defaultArtifactIndexPath(),
                                               receiptIndex: RepoPaths.defaultReceiptIndexPath(),
                                               anchorsPackHint: anchorsPackHint,
                                               out: nil,
                                               format: "human",
                                               groupByFix: true,
                                               onlyFail: false)
    let driftFixConfig = DriftFixService.Config(force: false,
                                                artifactIndex: RepoPaths.defaultArtifactIndexPath(),
                                                receiptIndex: RepoPaths.defaultReceiptIndexPath(),
                                                anchorsPackHint: anchorsPackHint ?? RepoPaths.defaultAnchorsPackHint(),
                                                yes: false,
                                                dryRun: true,
                                                out: nil,
                                                runsDir: runsDir)
    let readyConfig = ReadyService.Config(anchorsPackHint: readyAnchorsPackHint,
                                          artifactIndex: RepoPaths.defaultArtifactIndexPath(),
                                          runDir: nil,
                                          writeReport: true)
    let stationConfig = StationStatusService.Config(format: stationStatusFormat,
                                                    out: nil,
                                                    noWriteReport: stationNoWriteReport,
                                                    anchorsPackHint: RepoPaths.defaultAnchorsPackHint(),
                                                    runsDir: runsDir)
    let assetsConfig = AssetsService.ExportAllConfig(anchorsPack: assetsAnchorsPack,
                                                     overwrite: assetsOverwrite,
                                                     nonInteractive: assetsNonInteractive,
                                                     preflight: assetsPreflight,
                                                     runsDir: runsDir,
                                                     regionsConfig: RepoPaths.defaultRegionsConfigPath(),
                                                     racksOut: WubDefaults.packPath("ableton/racks/BASS_RACKS"),
                                                     performanceOut: WubDefaults.packPath("ableton/performance-sets/BASS_PERFORMANCE_SET_v1.0.als"),
                                                     baysSpec: WubDefaults.profileSpecPath("assets/export/finishing_bays_export.v1.yaml"),
                                                     serumOut: "library/serum/SERUM_BASE_v1.0.fxp",
                                                     extrasSpec: WubDefaults.profileSpecPath("assets/export/extra_exports.v1.yaml"),
                                                     postcheck: true,
                                                     rackVerifyManifest: WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json"),
                                                     vrlMapping: WubDefaults.profileSpecPath("voice/runtime/vrl_mapping.v1.yaml"),
                                                     force: false)
    let sessionProfilePath = WubDefaults.profileSpecPath("session/profiles/\(vrsSessionProfile).yaml")
    let sessionProfile = try SessionService.loadProfileConfig(profile: vrsSessionProfile, profilePath: sessionProfilePath)
    let sessionAnchors = vrsAnchorsPack ?? sessionProfile.anchorsPack
    let voiceMacroRegion = vrsMacroRegion.isEmpty ? sessionProfile.voiceMacroRegion : vrsMacroRegion
    let rackMacroRegion = vrsMacroRegion.isEmpty ? sessionProfile.rackMacroRegion : vrsMacroRegion
    let voiceConfig = VoiceService.RunConfig(script: sessionProfile.voiceScript,
                                             abi: sessionProfile.voiceAbi,
                                             anchorsPack: sessionAnchors,
                                             regions: sessionProfile.regionsPath,
                                             macroOcr: sessionProfile.voiceMacroOCR,
                                             macroRegion: voiceMacroRegion,
                                             fix: vrsFix,
                                             runsDir: runsDir)
    let rackInstallConfig = RackInstallService.Config(manifest: sessionProfile.rackManifest,
                                                      macroRegion: rackMacroRegion,
                                                      anchorsPack: sessionAnchors,
                                                      allowCgevent: vrsAllowCgevent,
                                                      runsDir: runsDir)
    let rackVerifyConfig = RackVerifyService.Config(manifest: sessionProfile.rackManifest,
                                                    macroRegion: rackMacroRegion,
                                                    runApply: true,
                                                    anchorsPack: sessionAnchors,
                                                    runsDir: runsDir)
    let sessionConfig = SessionService.Config(profile: vrsSessionProfile,
                                              profilePath: sessionProfilePath,
                                              anchorsPack: sessionAnchors,
                                              fix: vrsFix,
                                              runsDir: runsDir)
    let context = WubContext(runDir: runDir,
                             runsDir: runsDir,
                             sweeperConfig: sweeperConfig,
                             driftCheckConfig: driftCheckConfig,
                             driftFixConfig: driftFixConfig,
                             readyConfig: readyConfig,
                             stationConfig: stationConfig,
                             assetsConfig: assetsConfig,
                             voiceConfig: voiceConfig,
                             rackInstallConfig: rackInstallConfig,
                             rackVerifyConfig: rackVerifyConfig,
                             sessionConfig: sessionConfig,
                             indexConfig: IndexService.BuildConfig(repoVersion: indexRepoVersion,
                                                                   outDir: indexOutDir,
                                                                   runsDir: indexRunsDir),
                             releaseConfig: ReleaseService.PromoteConfig(profile: releaseProfilePath,
                                                                         out: nil,
                                                                         rackId: releaseRackId,
                                                                         macro: releaseMacro,
                                                                         baseline: releaseBaseline,
                                                                         currentSweep: releaseCurrentSweep,
                                                                         rackManifest: WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json"),
                                                                         runsDir: runsDir),
                             reportConfig: ReportService.GenerateConfig(runDir: reportRunDir, out: nil),
                             repairConfig: RepairService.Config(force: false,
                                                                anchorsPackHint: repairAnchorsPackHint,
                                                                yes: false,
                                                                overwrite: repairOverwrite,
                                                                runsDir: runsDir))
    let report = try context.makePlanReport()
    try emit(report, json: json)
  }
}

struct WubStateSetup: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "state-setup")

  @Option(name: .long, help: "Run directory to inspect (default: latest in \(RepoPaths.defaultRunsDir())/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: \(RepoPaths.defaultRunsDir())).")
  var runsDir: String = RepoPaths.defaultRunsDir()

  @Flag(name: .long, help: "Print manual steps after setup.")
  var showManual: Bool = false

  @Flag(name: .long, help: "Execute allowlisted steps (default: dry-run).")
  var apply: Bool = false

  func run() async throws {
    let context = WubContext(runDir: runDir,
                             runsDir: runsDir,
                             sweeperConfig: nil,
                             driftCheckConfig: nil,
                             driftFixConfig: nil,
                             readyConfig: nil,
                             stationConfig: nil,
                             assetsConfig: nil,
                             voiceConfig: nil,
                             rackInstallConfig: nil,
                             rackVerifyConfig: nil,
                             sessionConfig: nil,
                             indexConfig: nil,
                             releaseConfig: nil,
                             reportConfig: nil,
                             repairConfig: nil)
    let report = try context.makePlanReport()
    let evaluation = evaluateSetupSteps(report.steps, allowlist: stateSetupAllowlist)
    let (runId, setupRunDir) = try createSetupRunDir(runsDir: runsDir)
    let createdAt = ISO8601DateFormatter().string(from: Date())
    let planSteps = report.steps.map(setupStepRef)
    let skippedSteps = evaluation.skipped.map(setupSkippedStep)
    let manualSteps = evaluation.manual.map(setupStepRef)
    
    if !apply {
      print("Executable steps (dry run):")
      if evaluation.executable.isEmpty { print("- (none)") }
      for step in evaluation.executable {
        print("- \(step.agent)/\(step.id): \(step.description)")
      }
      if !evaluation.skipped.isEmpty {
        print("\nSkipped steps:")
        for (step, reason) in evaluation.skipped {
          print("- \(step.agent)/\(step.id): \(reason)")
        }
      }
      if showManual && !evaluation.manual.isEmpty {
        print("\nManual steps:")
        for step in evaluation.manual {
          print("- \(step.agent)/\(step.id): \(step.description)")
        }
      }
      let receipt = CreativeOSSetupReceiptV1(schemaVersion: 1,
                                             runId: runId,
                                             createdAt: createdAt,
                                             status: "dry_run",
                                             apply: false,
                                             allowlist: stateSetupAllowlist.sorted(),
                                             planSteps: planSteps,
                                             executedSteps: [],
                                             skippedSteps: skippedSteps,
                                             manualSteps: manualSteps,
                                             failures: [])
      let outPath = setupRunDir.appendingPathComponent("creative_os_setup_receipt.v1.json")
      try JSONIO.save(receipt, to: outPath)
      print("\nreceipt: \(outPath.path)")
      return
    }

    var failures: [String] = []
    var executed: [CreativeOSSetupReceiptV1.ExecutedStep] = []
    for step in evaluation.executable {
      let result = await executeStep(step, failures: &failures)
      executed.append(result)
    }

    if showManual && !evaluation.manual.isEmpty {
      print("\nManual steps:")
      for step in evaluation.manual {
        print("- \(step.agent)/\(step.id): \(step.description)")
      }
    }

    let status = failures.isEmpty ? "pass" : "fail"
    let receipt = CreativeOSSetupReceiptV1(schemaVersion: 1,
                                           runId: runId,
                                           createdAt: createdAt,
                                           status: status,
                                           apply: true,
                                           allowlist: stateSetupAllowlist.sorted(),
                                           planSteps: planSteps,
                                           executedSteps: executed,
                                           skippedSteps: skippedSteps,
                                           manualSteps: manualSteps,
                                           failures: failures)
    let outPath = setupRunDir.appendingPathComponent("creative_os_setup_receipt.v1.json")
    try JSONIO.save(receipt, to: outPath)
    print("\nreceipt: \(outPath.path)")

    if !failures.isEmpty {
      print("\nSetup failures:")
      for failure in failures { print("- \(failure)") }
      throw ExitCode(1)
    }
  }
}

struct WubSetup: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "setup",
    abstract: "Execute automated steps from state-plan."
  )

  @Option(name: .long, help: "Run directory to inspect (default: latest in \(RepoPaths.defaultRunsDir())/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: \(RepoPaths.defaultRunsDir())).")
  var runsDir: String = RepoPaths.defaultRunsDir()

  @Flag(name: .long, help: "Print manual steps after setup.")
  var showManual: Bool = false

  @Flag(name: .long, help: "Preview allowlisted steps without executing them.")
  var dryRun: Bool = false

  @Flag(name: .long, help: "Execute allowlisted steps (default: dry-run).")
  var apply: Bool = false

  func run() async throws {
    let context = WubContext(runDir: runDir,
                             runsDir: runsDir,
                             sweeperConfig: nil,
                             driftCheckConfig: nil,
                             driftFixConfig: nil,
                             readyConfig: nil,
                             stationConfig: nil,
                             assetsConfig: nil,
                             voiceConfig: nil,
                             rackInstallConfig: nil,
                             rackVerifyConfig: nil,
                             sessionConfig: nil,
                             indexConfig: nil,
                             releaseConfig: nil,
                             reportConfig: nil,
                             repairConfig: nil)
    let report = try context.makePlanReport()
    let evaluation = evaluateSetupSteps(report.steps, allowlist: stateSetupAllowlist)
    let (runId, setupRunDir) = try createSetupRunDir(runsDir: runsDir)
    let createdAt = ISO8601DateFormatter().string(from: Date())
    let planSteps = report.steps.map(setupStepRef)
    let skippedSteps = evaluation.skipped.map(setupSkippedStep)
    let manualSteps = evaluation.manual.map(setupStepRef)

    if apply && dryRun {
      throw ValidationError("Use either --apply or --dry-run (default: dry run).")
    }

    if !apply || dryRun {
      print("Executable steps (dry run):")
      if evaluation.executable.isEmpty { print("- (none)") }
      for step in evaluation.executable {
        print("- \(step.agent)/\(step.id): \(step.description)")
      }
      if !evaluation.skipped.isEmpty {
        print("\nSkipped steps:")
        for (step, reason) in evaluation.skipped {
          print("- \(step.agent)/\(step.id): \(reason)")
        }
      }
      if showManual && !evaluation.manual.isEmpty {
        print("\nManual steps:")
        for step in evaluation.manual {
          print("- \(step.agent)/\(step.id): \(step.description)")
        }
      }
      let receipt = CreativeOSSetupReceiptV1(schemaVersion: 1,
                                             runId: runId,
                                             createdAt: createdAt,
                                             status: "dry_run",
                                             apply: false,
                                             allowlist: stateSetupAllowlist.sorted(),
                                             planSteps: planSteps,
                                             executedSteps: [],
                                             skippedSteps: skippedSteps,
                                             manualSteps: manualSteps,
                                             failures: [])
      let outPath = setupRunDir.appendingPathComponent("creative_os_setup_receipt.v1.json")
      try JSONIO.save(receipt, to: outPath)
      print("\nreceipt: \(outPath.path)")
      return
    }

    var failures: [String] = []
    var executed: [CreativeOSSetupReceiptV1.ExecutedStep] = []
    for step in evaluation.executable {
      let result = await executeStep(step, failures: &failures)
      executed.append(result)
    }

    if showManual && !evaluation.manual.isEmpty {
      print("\nManual steps:")
      for step in evaluation.manual {
        print("- \(step.agent)/\(step.id): \(step.description)")
      }
    }

    let status = failures.isEmpty ? "pass" : "fail"
    let receipt = CreativeOSSetupReceiptV1(schemaVersion: 1,
                                           runId: runId,
                                           createdAt: createdAt,
                                           status: status,
                                           apply: true,
                                           allowlist: stateSetupAllowlist.sorted(),
                                           planSteps: planSteps,
                                           executedSteps: executed,
                                           skippedSteps: skippedSteps,
                                           manualSteps: manualSteps,
                                           failures: failures)
    let outPath = setupRunDir.appendingPathComponent("creative_os_setup_receipt.v1.json")
    try JSONIO.save(receipt, to: outPath)
    print("\nreceipt: \(outPath.path)")

    if !failures.isEmpty {
      print("\nSetup failures:")
      for failure in failures { print("- \(failure)") }
      throw ExitCode(1)
    }
  }
}

struct WubProfile: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "profile",
    subcommands: [WubProfileUse.self]
  )
}

struct WubStation: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "station",
    subcommands: [WubStationStatus.self]
  )
}

struct WubStationStatus: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "status",
    abstract: "Detect station state and emit station_state_report.v1.json."
  )

  @Option(name: .long, help: "Output format: human|json")
  var format: String = "human"

  @Option(name: .long, help: "Output path for JSON report (default \(RepoPaths.defaultRunsDir())/<run_id>/station_state_report.v1.json).")
  var out: String? = nil

  @Flag(name: .long, help: "Do not write report file; print only.")
  var noWriteReport: Bool = false

  @Option(name: .long, help: "Anchors pack hint (used only for evidence/reasons).")
  var anchorsPackHint: String = RepoPaths.defaultAnchorsPackHint()

  func run() async throws {
    var cmd = Station.Status()
    cmd.format = format
    cmd.out = out
    cmd.noWriteReport = noWriteReport
    cmd.anchorsPackHint = anchorsPackHint
    try await cmd.run()
  }
}

struct WubProfileUse: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "use")

  @Argument(help: "Profile id.")
  var profileId: String

  func run() async throws {
    let store = WubStore()
    let profiles = try store.loadProfiles()
    guard profiles.contains(where: { $0.id == profileId }) else {
      throw ValidationError("Unknown profile: \(profileId)")
    }
    var config = try store.loadOrCreateConfig(defaultProfileId: profiles.first?.id)
    config.activeProfileId = profileId
    config.lastUpdated = ISO8601DateFormatter().string(from: Date())
    try store.saveConfig(config)
    print("Selected profile: \(profileId)")
  }
}

private func emit<T: Encodable>(_ value: T, json: Bool) throws {
  if json {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try enc.encode(value)
    if let text = String(data: data, encoding: .utf8) { print(text) }
    return
  }
  printSummary(value)
}

let stateSetupAllowlist: Set<String> = CreativeOSActionCatalog.stateSetupAllowlist

struct SetupEvaluation {
  let executable: [CreativeOS.PlanStep]
  let skipped: [(CreativeOS.PlanStep, String)]
  let manual: [CreativeOS.PlanStep]
}

func evaluateSetupSteps(_ steps: [CreativeOS.PlanStep], allowlist: Set<String>) -> SetupEvaluation {
  for actionId in allowlist {
    guard CreativeOSActionCatalog.spec(for: actionId) != nil else {
      fatalError("state-setup allowlist contains unknown action id '\(actionId)' (missing from CreativeOSActionCatalog)")
    }
    guard ServiceExecutor.supports(actionId: actionId) else {
      fatalError("state-setup allowlist contains unsupported action id '\(actionId)' (no ServiceExecutor handler)")
    }
  }

  var executable: [CreativeOS.PlanStep] = []
  var skipped: [(CreativeOS.PlanStep, String)] = []
  var manual: [CreativeOS.PlanStep] = []

  for step in steps {
    guard let actionRef = step.actionRef else {
      manual.append(step)
      continue
    }
    if !allowlist.contains(actionRef.id) {
      skipped.append((step, "action not allowlisted (\(actionRef.id))"))
      continue
    }
    if !ServiceExecutor.supports(actionId: actionRef.id) {
      skipped.append((step, "action not supported by service executor (\(actionRef.id))"))
      continue
    }
    executable.append(step)
  }

  return SetupEvaluation(executable: executable, skipped: skipped, manual: manual)
}

private func printSummary<T>(_ value: T) {
  switch value {
  case let report as CreativeOS.SweepReport:
    print("SWEEP")
    print("observed slices: \(report.observed.slices.count)")
    print("desired slices: \(report.desired.slices.count)")
    print("checks: \(report.checks.count)")
    for c in report.checks { print("- \(c.agent)/\(c.id): \(c.severity.rawValue)") }
  case let report as CreativeOS.PlanReport:
    print("PLAN")
    print("observed slices: \(report.observed.slices.count)")
    print("desired slices: \(report.desired.slices.count)")
    print("steps: \(report.steps.count)")
    for s in report.steps { print("- \(s.agent)/\(s.id): \(s.type.rawValue)") }
  default:
    print(value)
  }
}

private func runShell(_ command: String) async throws -> Int32 {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/bin/bash")
  process.arguments = ["-lc", command]
  process.standardInput = FileHandle.standardInput
  process.standardOutput = FileHandle.standardOutput
  process.standardError = FileHandle.standardError
  try process.run()
  process.waitUntilExit()
  return process.terminationStatus
}

private func executeStep(_ step: CreativeOS.PlanStep, failures: inout [String]) async -> CreativeOSSetupReceiptV1.ExecutedStep {
  let start = ISO8601DateFormatter().string(from: Date())
  guard let actionRef = step.actionRef else {
    let finish = ISO8601DateFormatter().string(from: Date())
    let message = "\(step.agent)/\(step.id): missing action_ref"
    failures.append(message)
    return CreativeOSSetupReceiptV1.ExecutedStep(stepId: step.id,
                                                 agent: step.agent,
                                                 actionId: "missing_action_ref",
                                                 status: "error",
                                                 exitCode: nil,
                                                 error: message,
                                                 startedAt: start,
                                                 finishedAt: finish)
  }
  var status = "pass"
  var exitCode: Int? = nil
  var errorText: String? = nil
  do {
    print("Running: \(step.agent)/\(step.id) → \(actionRef.id)")
    if let spec = CreativeOSActionCatalog.spec(for: actionRef.id), spec.requiresStationGate {
      try StationGate.enforceOrThrow(force: false,
                                     anchorsPackHint: actionRef.kind == .setup ? RepoPaths.defaultAnchorsPackHint() : nil,
                                     commandName: actionRef.id)
    }
    if let code = try await ServiceExecutor.execute(step: step) {
      let codeInt = Int(code)
      exitCode = codeInt
      if codeInt != 0 {
        status = "fail"
        failures.append("\(step.agent)/\(step.id): exit=\(codeInt)")
      }
    }
  } catch {
    status = "error"
    errorText = String(describing: error)
    failures.append("\(step.agent)/\(step.id): \(error)")
  }
  let finish = ISO8601DateFormatter().string(from: Date())
  return CreativeOSSetupReceiptV1.ExecutedStep(stepId: step.id,
                                               agent: step.agent,
                                               actionId: actionRef.id,
                                               status: status,
                                               exitCode: exitCode,
                                               error: errorText,
                                               startedAt: start,
                                               finishedAt: finish)
}

private func createSetupRunDir(runsDir: String) throws -> (runId: String, runDir: URL) {
  let runId = RunContext.makeRunId()
  let runDir = URL(fileURLWithPath: runsDir).appendingPathComponent(runId, isDirectory: true)
  try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
  try FileManager.default.createDirectory(at: runDir.appendingPathComponent("evidence", isDirectory: true),
                                          withIntermediateDirectories: true)
  return (runId, runDir)
}

private func setupStepRef(_ step: CreativeOS.PlanStep) -> CreativeOSSetupReceiptV1.StepRef {
  CreativeOSSetupReceiptV1.StepRef(stepId: step.id, agent: step.agent, actionId: step.actionRef?.id)
}

private func setupSkippedStep(_ entry: (CreativeOS.PlanStep, String)) -> CreativeOSSetupReceiptV1.SkippedStep {
  let (step, reason) = entry
  return CreativeOSSetupReceiptV1.SkippedStep(stepId: step.id, agent: step.agent, actionId: step.actionRef?.id, reason: reason)
}

public enum WubEntry {
  public static func main() async {
    await WubCli.main()
  }
}
