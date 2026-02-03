import Foundation

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
