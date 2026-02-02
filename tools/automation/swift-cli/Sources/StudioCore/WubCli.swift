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
      LegacyPlan.self,
      Apply.self,
      WubSetup.self,

      // UI tooling
      CaptureAnchor.self,
      ValidateAnchors.self,
      CalibrateRegions.self,
      RegionsSelect.self,

      // Safety + ops
      DubSweeper.self,
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

  @Option(name: .long, help: "Run directory to inspect (default: latest in runs/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: runs).")
  var runsDir: String = "runs"

  @Flag(name: .long, help: "Output JSON.")
  var json: Bool = false

  func run() async throws {
    let context = WubContext(runDir: runDir, runsDir: runsDir, sweeperConfig: nil, driftConfig: nil, readyConfig: nil)
    let report = try context.makeSweepReport()
    try emit(report, json: json)
  }
}

struct WubSweep: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "sweep")

  @Option(name: .long, help: "Run directory to inspect (default: latest in runs/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: runs).")
  var runsDir: String = "runs"

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
    let config = SweeperConfig(anchorsPack: anchorsPack,
                               modalTest: modalTest,
                               requiredControllers: requireController,
                               allowOcrFallback: allowOcrFallback,
                               fix: fix)
    let context = WubContext(runDir: runDir, runsDir: runsDir, sweeperConfig: config, driftConfig: nil, readyConfig: nil)
    let report = try context.makeSweepReport()
    try emit(report, json: json)
  }
}

struct WubStatePlan: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "state-plan")

  @Option(name: .long, help: "Run directory to inspect (default: latest in runs/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: runs).")
  var runsDir: String = "runs"

  @Flag(name: .long, help: "Output JSON.")
  var json: Bool = false

  func run() async throws {
    let context = WubContext(runDir: runDir, runsDir: runsDir, sweeperConfig: nil, driftConfig: nil, readyConfig: nil)
    let report = try context.makePlanReport()
    try emit(report, json: json)
  }
}

struct WubPlan: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "plan")

  @Option(name: .long, help: "Run directory to inspect (default: latest in runs/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: runs).")
  var runsDir: String = "runs"

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
  var readyAnchorsPackHint: String = "specs/automation/anchors/<pack_id>"

  func run() async throws {
    let config = SweeperConfig(anchorsPack: anchorsPack,
                               modalTest: modalTest,
                               requiredControllers: requireController,
                               allowOcrFallback: allowOcrFallback,
                               fix: fix)
    let context = WubContext(runDir: runDir,
                             runsDir: runsDir,
                             sweeperConfig: config,
                             driftConfig: DriftConfig(anchorsPackHint: anchorsPackHint),
                             readyConfig: ReadyConfig(anchorsPackHint: readyAnchorsPackHint))
    let report = try context.makePlanReport()
    try emit(report, json: json)
  }
}

struct WubStateSetup: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "state-setup")

  @Option(name: .long, help: "Run directory to inspect (default: latest in runs/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: runs).")
  var runsDir: String = "runs"

  @Flag(name: .long, help: "Print manual steps after setup.")
  var showManual: Bool = false

  func run() async throws {
    let context = WubContext(runDir: runDir, runsDir: runsDir, sweeperConfig: nil, driftConfig: nil, readyConfig: nil)
    let report = try context.makePlanReport()
    let automated = report.steps.filter { $0.type == .automated }
    let manual = report.steps.filter { $0.type == .manualRequired }

    if automated.isEmpty {
      print("No automated steps available. Use 'wub state-plan' for manual steps.")
      if showManual && !manual.isEmpty {
        print("\nManual steps:")
        for step in manual {
          print("- \(step.agent)/\(step.id): \(step.description)")
        }
      }
      return
    }

    var failures: [String] = []
    for step in automated {
      let processEffects = step.effects.filter { $0.kind == .process }
      if processEffects.isEmpty {
        failures.append("\(step.agent)/\(step.id): no process effects to execute")
        continue
      }
      for effect in processEffects {
        print("Running: \(step.agent)/\(step.id) → \(effect.target)")
        let code = try await runShell(effect.target)
        if code != 0 {
          failures.append("\(step.agent)/\(step.id): exit=\(code)")
        }
      }
    }

    if showManual && !manual.isEmpty {
      print("\nManual steps:")
      for step in manual {
        print("- \(step.agent)/\(step.id): \(step.description)")
      }
    }

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

  @Option(name: .long, help: "Run directory to inspect (default: latest in runs/).")
  var runDir: String? = nil

  @Option(name: .long, help: "Runs directory (default: runs).")
  var runsDir: String = "runs"

  @Flag(name: .long, help: "Print manual steps after setup.")
  var showManual: Bool = false

  @Flag(name: .long, help: "Preview automated steps without executing them.")
  var dryRun: Bool = false

  func run() async throws {
    let context = WubContext(runDir: runDir, runsDir: runsDir, sweeperConfig: nil, driftConfig: nil, readyConfig: nil)
    let report = try context.makePlanReport()
    let automated = report.steps.filter { $0.type == .automated }
    let manual = report.steps.filter { $0.type == .manualRequired }

    if automated.isEmpty {
      print("No automated steps available. Use 'wub state-plan' for manual steps.")
      if showManual && !manual.isEmpty {
        print("\nManual steps:")
        for step in manual {
          print("- \(step.agent)/\(step.id): \(step.description)")
        }
      }
      return
    }

    if dryRun {
      print("Automated steps (dry run):")
      for step in automated {
        print("- \(step.agent)/\(step.id): \(step.description)")
      }
      if showManual && !manual.isEmpty {
        print("\nManual steps:")
        for step in manual {
          print("- \(step.agent)/\(step.id): \(step.description)")
        }
      }
      return
    }

    var failures: [String] = []
    for step in automated {
      let processEffects = step.effects.filter { $0.kind == .process }
      if processEffects.isEmpty {
        failures.append("\(step.agent)/\(step.id): no process effects to execute")
        continue
      }
      for effect in processEffects {
        print("Running: \(step.agent)/\(step.id) → \(effect.target)")
        let code = try await runShell(effect.target)
        if code != 0 {
          failures.append("\(step.agent)/\(step.id): exit=\(code)")
        }
      }
    }

    if showManual && !manual.isEmpty {
      print("\nManual steps:")
      for step in manual {
        print("- \(step.agent)/\(step.id): \(step.description)")
      }
    }

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

  @Option(name: .long, help: "Output path for JSON report (default runs/<run_id>/station_state_report.v1.json).")
  var out: String? = nil

  @Flag(name: .long, help: "Do not write report file; print only.")
  var noWriteReport: Bool = false

  @Option(name: .long, help: "Anchors pack hint (used only for evidence/reasons).")
  var anchorsPackHint: String = "specs/automation/anchors/<pack_id>"

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

public enum WubEntry {
  public static func main() async {
    await WubCli.main()
  }
}
