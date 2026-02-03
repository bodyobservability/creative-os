import Foundation
import ArgumentParser

struct CommonOptions: ParsableArguments {
  @Flag(name: .long) var interactive: Bool = false
  @Option(name: .long) var runsDir: String = "runs"
  @Option(name: .long) var ableton: String = "12.3"
  @Option(name: .long) var serum: String = "2"
  @Option(name: .long) var preferredFormats: String = "au,vst3"
  @Option(name: .long) var regionsConfig: String = "kernel/cli/config/regions.v1.json"
  @Option(name: .long, help: "Evidence capture: none | fail | all (default: fail).")
  var evidence: String = "fail"
  @Option(name: .long) var substitutions: String = "shared/specs/automation/substitutions/substitutions.v1.json"
  @Option(name: .long) var recommendations: String = "shared/specs/automation/recommendations/recommendations.v1.json"
  @Option(name: .long) var packSignatures: String = "shared/specs/automation/recommendations/pack_signatures.v1.json"
}

enum WubPaths {
  static let operatorRoot = "operator"

  static func operatorPath(_ components: [String]) -> String {
    ([operatorRoot] + components).joined(separator: "/")
  }

  static let operatorProfilesDir = operatorPath(["profiles"])
  static let operatorPacksDir = operatorPath(["packs"])
  static let operatorNotesDir = operatorPath(["notes"])
  static let operatorConfigPath = operatorPath(["notes", "WUB_CONFIG.json"])
  static let operatorLocalConfigPath = operatorPath(["notes", "LOCAL_CONFIG.json"])
}


enum WubDefaults {
  private static func loadConfig(using store: WubStore) -> WubConfig? {
    let url = URL(fileURLWithPath: store.configPath)
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try? JSONIO.load(WubConfig.self, from: url)
  }

  static func activeProfile() -> CreativeOS.Profile? {
    let store = WubStore()
    guard let profiles = try? store.loadProfiles(), !profiles.isEmpty else { return nil }
    let config = loadConfig(using: store)
    if let id = config?.activeProfileId,
       let profile = profiles.first(where: { $0.id == id }) {
      return profile
    }
    return profiles.first
  }

  static func activeProfileId() -> String? {
    activeProfile()?.id
  }

  static func activePackId() -> String? {
    let store = WubStore()
    guard let profiles = try? store.loadProfiles(), !profiles.isEmpty else { return nil }
    let config = loadConfig(using: store)
    if let packId = config?.activePackIds.first { return packId }
    let profile = profiles.first(where: { $0.id == config?.activeProfileId }) ?? profiles.first
    return profile?.packs.first
  }

  static func profileSpecPath(_ relative: String) -> String {
    if let id = activeProfileId() {
      return "shared/specs/profiles/\(id)/\(relative)"
    }
    return "shared/specs/profiles/NO_PROFILE/\(relative)"
  }

  static func packPath(_ relative: String) -> String {
    if let id = activePackId() {
      return WubPaths.operatorPath(["packs", id, relative])
    }
    return WubPaths.operatorPath(["packs", "NO_PACK", relative])
  }
}

struct RunContext {
  let runId: String
  let runDir: URL
  let preferredFormats: [String]

  init(common: CommonOptions) {
    runId = RunContext.makeRunId()
    runDir = URL(fileURLWithPath: common.runsDir).appendingPathComponent(runId, isDirectory: true)
    preferredFormats = common.preferredFormats.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
  }

  func ensureRunDir() throws {
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: runDir.appendingPathComponent("evidence", isDirectory: true), withIntermediateDirectories: true)
  }

  static func makeRunId() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd_HHmmss"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.string(from: Date())
  }
}

enum JSONIO {
  static func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
    try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
  }
  static func save<T: Encodable>(_ obj: T, to url: URL) throws {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try enc.encode(obj)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: [.atomic])
  }
}

enum ConsolePrinter {
  static func printReportSummary(_ report: ResolveReport) {
    print("\n== Resolve Report ==")
    print("Generated: \(report.generatedAt)")
    print("Prompts: \(report.prompts.count)")
    for p in report.prompts.prefix(10) { print("- [\(p.type)] \(p.title)") }
  }
}

enum InteractivePromptLoop {
  static func run(prompts: [Prompt], runDir: URL) throws {
    for p in prompts {
      print("\n[\(p.type.uppercased())] \(p.title)")
      print(p.message)
      print("\n[o] open folder  [q] quit  [enter] continue")
      let choice = readLine() ?? ""
      if choice.lowercased() == "o" {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = [runDir.path]
        try? proc.run()
      }
      if choice.lowercased() == "q" { throw ExitCode(2) }
    }
  }
}

func reportExitCode(_ report: ResolveReport) -> Int32 {
  let blockers: Set<String> = ["install_pack","install_plugin","install_plugin_or_pack","connect_controller","configure_controller"]
  return report.prompts.contains { blockers.contains($0.type) } ? 1 : 0
}
