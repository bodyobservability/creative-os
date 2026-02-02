import Foundation
import Yams

struct WubContext {
  let runDir: String?
  let runsDir: String
  let sweeperConfig: SweeperConfig?
  let driftConfig: DriftConfig?
  let readyConfig: ReadyConfig?

  func makeSweepReport() throws -> CreativeOS.SweepReport {
    let runtime = try buildRuntime()
    return try runtime.sweep()
  }

  func makePlanReport() throws -> CreativeOS.PlanReport {
    let runtime = try buildRuntime()
    return try runtime.plan()
  }

  private func buildRuntime() throws -> CreativeOS.Runtime {
    let store = WubStore()
    let profiles = try store.loadProfiles()
    let config = try store.loadOrCreateConfig(defaultProfileId: profiles.first?.id)
    guard let profile = profiles.first(where: { $0.id == config.activeProfileId }) else {
      return CreativeOS.Runtime(agents: [], profile: nil)
    }

    var agents: [CreativeOS.Agent] = [ProfileAgent(profile: profile), MappingAgent()]
    if let sweeperConfig {
      agents.append(SweeperAgent(config: sweeperConfig))
    }
    if let driftConfig { agents.append(DriftAgent(config: driftConfig)) }
    if let readyConfig { agents.append(ReadyAgent(config: readyConfig)) }
    if !config.activePackIds.isEmpty {
      let packs = try store.loadPackManifests()
      let selected = packs.filter { config.activePackIds.contains($0.id) }
      agents.append(contentsOf: selected.map { PackAgent(pack: $0) })
    }

    return CreativeOS.Runtime(agents: agents, profile: profile)
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
