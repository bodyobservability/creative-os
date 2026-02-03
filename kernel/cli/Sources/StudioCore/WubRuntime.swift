import Foundation
import Yams

struct WubContext {
  let storeRoot: URL
  let runDir: String?
  let runsDir: String
  let sweeperConfig: SweeperService.Config?
  let driftCheckConfig: DriftService.Config?
  let driftFixConfig: DriftFixService.Config?
  let readyConfig: ReadyService.Config?
  let stationConfig: StationStatusService.Config?
  let assetsConfig: AssetsService.ExportAllConfig?
  let voiceConfig: VoiceService.RunConfig?
  let rackInstallConfig: RackInstallService.Config?
  let rackVerifyConfig: RackVerifyService.Config?
  let sessionConfig: SessionService.Config?
  let indexConfig: IndexService.BuildConfig?
  let releaseConfig: ReleaseService.PromoteConfig?
  let reportConfig: ReportService.GenerateConfig?
  let repairConfig: RepairService.Config?

  init(runDir: String?,
       runsDir: String,
       sweeperConfig: SweeperService.Config?,
       driftCheckConfig: DriftService.Config?,
       driftFixConfig: DriftFixService.Config?,
       readyConfig: ReadyService.Config?,
       stationConfig: StationStatusService.Config?,
       assetsConfig: AssetsService.ExportAllConfig?,
       voiceConfig: VoiceService.RunConfig?,
       rackInstallConfig: RackInstallService.Config?,
       rackVerifyConfig: RackVerifyService.Config?,
       sessionConfig: SessionService.Config?,
       indexConfig: IndexService.BuildConfig?,
       releaseConfig: ReleaseService.PromoteConfig?,
       reportConfig: ReportService.GenerateConfig?,
       repairConfig: RepairService.Config?,
       storeRoot: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) {
    self.storeRoot = storeRoot
    self.runDir = runDir
    self.runsDir = runsDir
    self.sweeperConfig = sweeperConfig
    self.driftCheckConfig = driftCheckConfig
    self.driftFixConfig = driftFixConfig
    self.readyConfig = readyConfig
    self.stationConfig = stationConfig
    self.assetsConfig = assetsConfig
    self.voiceConfig = voiceConfig
    self.rackInstallConfig = rackInstallConfig
    self.rackVerifyConfig = rackVerifyConfig
    self.sessionConfig = sessionConfig
    self.indexConfig = indexConfig
    self.releaseConfig = releaseConfig
    self.reportConfig = reportConfig
    self.repairConfig = repairConfig
  }

  func makeSweepReport() throws -> CreativeOS.SweepReport {
    let runtime = try buildRuntime()
    return try runtime.sweep()
  }

  func makePlanReport() throws -> CreativeOS.PlanReport {
    let runtime = try buildRuntime()
    return try runtime.plan()
  }

  private func buildRuntime() throws -> CreativeOS.Runtime {
    let store = WubStore(root: storeRoot)
    let profiles = try store.loadProfiles()
    let config = try store.loadOrCreateConfig(defaultProfileId: profiles.first?.id)
    guard let profile = profiles.first(where: { $0.id == config.activeProfileId }) else {
      return CreativeOS.Runtime(agents: [], profile: nil)
    }

    var agents: [CreativeOS.Agent] = [ProfileAgent(profile: profile), MappingAgent()]
    if let sweeperConfig {
      agents.append(SweeperAgent(config: sweeperConfig))
    }
    if let driftCheckConfig, let driftFixConfig {
      agents.append(DriftAgent(checkConfig: driftCheckConfig, fixConfig: driftFixConfig))
    }
    if let readyConfig { agents.append(ReadyAgent(config: readyConfig)) }
    if let stationConfig { agents.append(StationAgent(config: stationConfig)) }
    if let assetsConfig { agents.append(AssetsAgent(config: assetsConfig)) }
    if let voiceConfig, let rackInstallConfig, let rackVerifyConfig, let sessionConfig {
      agents.append(VoiceRackSessionAgent(voiceConfig: voiceConfig,
                                          rackInstallConfig: rackInstallConfig,
                                          rackVerifyConfig: rackVerifyConfig,
                                          sessionConfig: sessionConfig))
    }
    if let indexConfig { agents.append(IndexAgent(config: indexConfig)) }
    if let releaseConfig { agents.append(ReleaseAgent(config: releaseConfig)) }
    if let reportConfig { agents.append(ReportAgent(config: reportConfig)) }
    if let repairConfig { agents.append(RepairAgent(config: repairConfig)) }
    if !config.activePackIds.isEmpty {
      let packs = try store.loadPackManifests()
      let selected = packs.filter { config.activePackIds.contains($0.id) }
      agents.append(contentsOf: selected.map { PackAgent(pack: $0) })
    }

    return CreativeOS.Runtime(agents: agents, profile: profile)
  }
}

struct WubStore {
  let root: URL
  let profilesDir: String
  let configPath: String
  let packsDir: String

  init(root: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
       profilesDir: String = WubPaths.operatorProfilesDir,
       configPath: String = WubPaths.operatorConfigPath,
       packsDir: String = WubPaths.operatorPacksDir) {
    self.root = root
    self.profilesDir = profilesDir
    self.configPath = configPath
    self.packsDir = packsDir
  }

  private var profilesURL: URL { root.appendingPathComponent(profilesDir, isDirectory: true) }
  private var packsURL: URL { root.appendingPathComponent(packsDir, isDirectory: true) }
  private var configURL: URL { root.appendingPathComponent(configPath) }

  func loadProfiles() throws -> [CreativeOS.Profile] {
    guard FileManager.default.fileExists(atPath: profilesURL.path) else { return [] }
    let entries = try FileManager.default.contentsOfDirectory(atPath: profilesURL.path)
    let files = entries.filter { $0.hasSuffix(".profile.yaml") }.sorted()
    var profiles: [CreativeOS.Profile] = []
    for name in files {
      let path = profilesURL.appendingPathComponent(name).path
      let yaml = try String(contentsOfFile: path, encoding: .utf8)
      let profile = try YAMLDecoder().decode(CreativeOS.Profile.self, from: yaml)
      profiles.append(profile)
    }
    return profiles
  }

  func loadPackManifests() throws -> [CreativeOS.PackManifest] {
    guard FileManager.default.fileExists(atPath: packsURL.path) else { return [] }
    let entries = try FileManager.default.contentsOfDirectory(atPath: packsURL.path)
    var packPaths: [String] = []

    for name in entries.sorted() {
      let path = packsURL.appendingPathComponent(name).path
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
    if FileManager.default.fileExists(atPath: configURL.path) {
      return try JSONIO.load(WubConfig.self, from: configURL)
    }
    let fallbackId = defaultProfileId ?? "default"
    let config = WubConfig(activeProfileId: fallbackId,
                           activePackIds: [],
                           lastUpdated: ISO8601DateFormatter().string(from: Date()))
    try saveConfig(config)
    return config
  }

  func saveConfig(_ config: WubConfig) throws {
    try JSONIO.save(config, to: configURL)
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
