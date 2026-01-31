import Foundation

struct LocalConfig: Codable {
  var anchorsPack: String?

  static func path(atRepoRoot root: String) -> String {
    return URL(fileURLWithPath: root).appendingPathComponent("notes/LOCAL_CONFIG.json").path
  }

  static func loadOrCreate(atRepoRoot root: String) throws -> LocalConfig {
    let p = path(atRepoRoot: root)
    if FileManager.default.fileExists(atPath: p) {
      let data = try Data(contentsOf: URL(fileURLWithPath: p))
      return try JSONDecoder().decode(LocalConfig.self, from: data)
    }
    // create default config (but do not force anchorsPack)
    let cfg = LocalConfig(anchorsPack: nil)
    try cfg.save(atRepoRoot: root)
    return cfg
  }

  func save(atRepoRoot root: String) throws {
    let p = LocalConfig.path(atRepoRoot: root)
    let dir = URL(fileURLWithPath: p).deletingLastPathComponent()
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(self)
    try data.write(to: URL(fileURLWithPath: p), options: [.atomic])
  }
}
