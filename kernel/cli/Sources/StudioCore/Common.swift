import Foundation
import ArgumentParser

struct CommonOptions: ParsableArguments {
  @Flag(name: .long) var interactive: Bool = false
  @Option(name: .long) var runsDir: String = RepoPaths.defaultRunsDir()
  @Option(name: .long) var ableton: String = "12.3"
  @Option(name: .long) var serum: String = "2"
  @Option(name: .long) var preferredFormats: String = "au,vst3"
  @Option(name: .long) var regionsConfig: String = RepoPaths.defaultRegionsConfigPath()
  @Option(name: .long, help: "Evidence capture: none | fail | all (default: fail).")
  var evidence: String = "fail"
  @Option(name: .long) var substitutions: String = RepoPaths.defaultSubstitutionsPath()
  @Option(name: .long) var recommendations: String = RepoPaths.defaultRecommendationsPath()
  @Option(name: .long) var packSignatures: String = RepoPaths.defaultPackSignaturesPath()
}

enum WubPaths {
  static func operatorPath(_ components: [String]) -> String {
    let root = RepoPaths.rootURL()
    let base = RepoPaths.operatorDir(root: root)
    let full = components.reduce(base) { $0.appendingPathComponent($1) }
    return RepoPaths.relPath(root: root, url: full)
  }

  static var operatorProfilesDir: String { operatorPath(["profiles"]) }
  static var operatorPacksDir: String { operatorPath(["packs"]) }
  static var operatorNotesDir: String { operatorPath(["notes"]) }
  static var operatorConfigPath: String { operatorPath(["notes", "WUB_CONFIG.json"]) }
  static var operatorLocalConfigPath: String { operatorPath(["notes", "LOCAL_CONFIG.json"]) }
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
    let root = RepoPaths.rootURL()
    if let id = activeProfileId() {
      let path = RepoPaths.sharedProfileSpecsDir(root: root, profileId: id).appendingPathComponent(relative)
      return RepoPaths.relPath(root: root, url: path)
    }
    let fallback = RepoPaths.sharedProfileSpecsDir(root: root, profileId: "NO_PROFILE").appendingPathComponent(relative)
    return RepoPaths.relPath(root: root, url: fallback)
  }

  static func packPath(_ relative: String) -> String {
    let root = RepoPaths.rootURL()
    if let id = activePackId() {
      let path = RepoPaths.packsDir(root: root).appendingPathComponent(id, isDirectory: true).appendingPathComponent(relative)
      return RepoPaths.relPath(root: root, url: path)
    }
    let fallback = RepoPaths.packsDir(root: root).appendingPathComponent("NO_PACK", isDirectory: true).appendingPathComponent(relative)
    return RepoPaths.relPath(root: root, url: fallback)
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
