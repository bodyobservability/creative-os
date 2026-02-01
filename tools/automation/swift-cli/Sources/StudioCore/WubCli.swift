import ArgumentParser
import Foundation
import Yams

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
      Plan.self,
      Apply.self,

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
    let context = WubContext(runDir: runDir, runsDir: runsDir)
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
    let context = WubContext(runDir: runDir, runsDir: runsDir)
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
    let context = WubContext(runDir: runDir, runsDir: runsDir)
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

struct WubContext {
  let runDir: String?
  let runsDir: String

  func makeSweepReport() throws -> CreativeOS.SweepReport {
    var checks: [CreativeOS.CheckResult] = []
    let desired = try desiredState()
    let observed = try observedState()
    let mappingIssues = CreativeOSMapping.validate()

    if !mappingIssues.isEmpty {
      checks.append(CreativeOS.CheckResult(id: "migration_mapping_validation",
                                           agent: "runtime",
                                           severity: .warn,
                                           category: .policy,
                                           observed: .array(mappingIssues.map { .string($0) }),
                                           expected: nil,
                                           evidence: [
                                            CreativeOS.EvidenceItem(id: "mapping_table", kind: "mapping", path: "docs/creative_os_mapping.md", details: nil)
                                           ],
                                           suggestedActions: []))
    }

    let ordered = checks.sorted { ($0.agent, $0.id) < ($1.agent, $1.id) }
    return CreativeOS.SweepReport(observed: observed,
                                  desired: desired,
                                  checks: ordered)
  }

  func makePlanReport() throws -> CreativeOS.PlanReport {
    var steps: [CreativeOS.PlanStep] = []
    let desired = try desiredState()
    let observed = try observedState()
    let mappingIssues = CreativeOSMapping.validate()

    steps.append(contentsOf: diffObservedDesired(observed: observed, desired: desired))

    if let sweeper = loadSweeperReport() {
      steps.append(contentsOf: planSteps(from: sweeper))
    }

    if !mappingIssues.isEmpty {
      steps.append(CreativeOS.PlanStep(id: "migration_mapping_validation",
                                       agent: "runtime",
                                       type: .manualRequired,
                                       description: "Resolve migration mapping validation issues",
                                       effects: [],
                                       idempotent: true,
                                       manualReason: "mapping_validation"))
    }

    let ordered = steps.sorted { ($0.agent, $0.id) < ($1.agent, $1.id) }
    return CreativeOS.PlanReport(observed: observed,
                                 desired: desired,
                                 steps: ordered)
  }



  private func resolveRunDirPath() -> String? {
    if let runDir { return runDir }
    let fm = FileManager.default
    guard fm.fileExists(atPath: runsDir) else { return nil }
    guard let entries = try? fm.contentsOfDirectory(atPath: runsDir) else { return nil }
    let dirs = entries.sorted().reversed()
    for name in dirs {
      let path = "\(runsDir)/\(name)"
      var isDir: ObjCBool = false
      if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
        return path
      }
    }
    return nil
  }

  private func loadSweeperReport() -> DubSweeperReportV1? {
    guard let dir = resolveRunDirPath() else { return nil }
    let path = "\(dir)/sweeper_report.v1.json"
    guard FileManager.default.fileExists(atPath: path) else { return nil }
    return try? JSONIO.load(DubSweeperReportV1.self, from: URL(fileURLWithPath: path))
  }

  private func planSteps(from sweeper: DubSweeperReportV1) -> [CreativeOS.PlanStep] {
    var steps: [CreativeOS.PlanStep] = []
    for step in sweeper.safeSteps {
      steps.append(CreativeOS.PlanStep(id: step.id,
                                       agent: "sweeper",
                                       type: .manualRequired,
                                       description: step.description,
                                       effects: [],
                                       idempotent: true,
                                       manualReason: "sweep_safe"))
    }
    for step in sweeper.manualSteps {
      steps.append(CreativeOS.PlanStep(id: step.id,
                                       agent: "sweeper",
                                       type: .manualRequired,
                                       description: step.description,
                                       effects: [],
                                       idempotent: true,
                                       manualReason: "sweep_manual"))
    }
    return steps
  }

  private func desiredState() throws -> CreativeOS.DesiredState {
    let store = WubStore()
    let profiles = try store.loadProfiles()
    let config = try store.loadOrCreateConfig(defaultProfileId: profiles.first?.id)
    guard let profile = profiles.first(where: { $0.id == config.activeProfileId }) else {
      return CreativeOS.DesiredState(slices: [])
    }
    var slices: [CreativeOS.DesiredStateSlice] = [profileSlice(from: profile)]

    if !config.activePackIds.isEmpty {
      let packs = try store.loadPackManifests()
      let selected = packs.filter { config.activePackIds.contains($0.id) }
      slices.append(contentsOf: selected.map { packSlice(from: $0) })
    }

    return CreativeOS.DesiredState(slices: slices)
  }

  private func profileSlice(from profile: CreativeOS.Profile) -> CreativeOS.DesiredStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(profile.id),
      "intents": .array(profile.intents.map { .string($0) }),
      "policies": .object(profile.policies),
      "requirements": .object(profile.requirements),
      "packs": .array(profile.packs.map { .string($0) })
    ])
    return CreativeOS.DesiredStateSlice(agentId: "profile", data: nil, raw: json)
  }

  private func observedState() throws -> CreativeOS.ObservedState {
    let store = WubStore()
    let profiles = try store.loadProfiles()
    let config = try store.loadOrCreateConfig(defaultProfileId: profiles.first?.id)
    guard let profile = profiles.first(where: { $0.id == config.activeProfileId }) else {
      return CreativeOS.ObservedState(slices: [])
    }

    var slices: [CreativeOS.ObservedStateSlice] = [profileObservedSlice(from: profile)]

    if !config.activePackIds.isEmpty {
      let packs = try store.loadPackManifests()
      let selected = packs.filter { config.activePackIds.contains($0.id) }
      slices.append(contentsOf: selected.map { packObservedSlice(from: $0) })
    }

    return CreativeOS.ObservedState(slices: slices)
  }

  private func profileObservedSlice(from profile: CreativeOS.Profile) -> CreativeOS.ObservedStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(profile.id),
      "intents": .array(profile.intents.map { .string($0) }),
      "policies": .object(profile.policies),
      "requirements": .object(profile.requirements),
      "packs": .array(profile.packs.map { .string($0) })
    ])
    return CreativeOS.ObservedStateSlice(agentId: "profile", data: nil, raw: json)
  }

  private func packSlice(from pack: CreativeOS.PackManifest) -> CreativeOS.DesiredStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(pack.id),
      "applies_to": .array(pack.appliesTo.map { .string($0) }),
      "contents": .object(pack.contents),
      "requires_explicit_apply": .bool(pack.requiresExplicitApply)
    ])
    return CreativeOS.DesiredStateSlice(agentId: "pack:\(pack.id)", data: nil, raw: json)
  }

  private func packObservedSlice(from pack: CreativeOS.PackManifest) -> CreativeOS.ObservedStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(pack.id),
      "applies_to": .array(pack.appliesTo.map { .string($0) }),
      "contents": .object(pack.contents),
      "requires_explicit_apply": .bool(pack.requiresExplicitApply)
    ])
    return CreativeOS.ObservedStateSlice(agentId: "pack:\(pack.id)", data: nil, raw: json)
  }

  private func diffObservedDesired(observed: CreativeOS.ObservedState,
                                   desired: CreativeOS.DesiredState) -> [CreativeOS.PlanStep] {
    let observedByAgent = Dictionary(uniqueKeysWithValues: observed.slices.map { ($0.agentId, $0) })
    let desiredSorted = desired.slices.sorted { $0.agentId < $1.agentId }
    var steps: [CreativeOS.PlanStep] = []

    for desiredSlice in desiredSorted {
      guard let observedSlice = observedByAgent[desiredSlice.agentId] else {
        steps.append(CreativeOS.PlanStep(id: "state_missing_\(desiredSlice.agentId)",
                                         agent: desiredSlice.agentId,
                                         type: .manualRequired,
                                         description: "Provide observed state slice for agent \(desiredSlice.agentId)",
                                         effects: [],
                                         idempotent: true,
                                         manualReason: "observed_state_missing"))
        continue
      }
      if !stateMatches(observed: observedSlice, desired: desiredSlice) {
        steps.append(CreativeOS.PlanStep(id: "state_mismatch_\(desiredSlice.agentId)",
                                         agent: desiredSlice.agentId,
                                         type: .manualRequired,
                                         description: "Align observed state for agent \(desiredSlice.agentId) with desired policy",
                                         effects: [],
                                         idempotent: true,
                                         manualReason: "state_diff"))
      }
    }

    return steps
  }

  private func stateMatches(observed: CreativeOS.ObservedStateSlice,
                            desired: CreativeOS.DesiredStateSlice) -> Bool {
    if observed.agentId != desired.agentId { return false }
    if observed.data != desired.data { return false }
    if observed.raw != desired.raw { return false }
    return true
  }

}

struct WubStore {
  let profilesDir = "profiles"
  let configPath = "notes/WUB_CONFIG.json"
  let packsDir = "packs"

  func loadProfiles() throws -> [CreativeOS.Profile] {
    guard FileManager.default.fileExists(atPath: profilesDir) else { return [] }
    let entries = try FileManager.default.contentsOfDirectory(atPath: profilesDir)
    let files = entries.filter { $0.hasSuffix(".profile.yaml") }.sorted()
    var profiles: [CreativeOS.Profile] = []
    for name in files {
      let path = "\(profilesDir)/\(name)"
      let yaml = try String(contentsOfFile: path, encoding: .utf8)
      let profile = try YAMLDecoder().decode(CreativeOS.Profile.self, from: yaml)
      profiles.append(profile)
    }
    return profiles
  }

  func loadPackManifests() throws -> [CreativeOS.PackManifest] {
    guard FileManager.default.fileExists(atPath: packsDir) else { return [] }
    let entries = try FileManager.default.contentsOfDirectory(atPath: packsDir)
    var packPaths: [String] = []

    for name in entries.sorted() {
      let path = "\(packsDir)/\(name)"
      var isDir: ObjCBool = false
      if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
        let candidate = "\(path)/pack.yaml"
        if FileManager.default.fileExists(atPath: candidate) {
          packPaths.append(candidate)
        }
      } else if name == "pack.yaml" || name.hasSuffix(".pack.yaml") {
        packPaths.append(path)
      }
    }

    var packs: [CreativeOS.PackManifest] = []
    for path in packPaths {
      let yaml = try String(contentsOfFile: path, encoding: .utf8)
      let pack = try YAMLDecoder().decode(CreativeOS.PackManifest.self, from: yaml)
      packs.append(pack)
    }
    return packs
  }

  func loadOrCreateConfig(defaultProfileId: String?) throws -> WubConfig {
    if FileManager.default.fileExists(atPath: configPath) {
      return try JSONIO.load(WubConfig.self, from: URL(fileURLWithPath: configPath))
    }
    let fallbackId = defaultProfileId ?? "default"
    let config = WubConfig(activeProfileId: fallbackId,
                           activePackIds: [],
                           lastUpdated: ISO8601DateFormatter().string(from: Date()))
    try saveConfig(config)
    return config
  }

  func saveConfig(_ config: WubConfig) throws {
    try JSONIO.save(config, to: URL(fileURLWithPath: configPath))
  }
}

struct WubConfig: Codable {
  var activeProfileId: String
  var activePackIds: [String]
  var lastUpdated: String

  enum CodingKeys: String, CodingKey {
    case activeProfileId = "active_profile_id"
    case activePackIds = "active_pack_ids"
    case lastUpdated = "last_updated"
  }
}
