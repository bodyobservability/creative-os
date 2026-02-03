import Foundation

struct BaselineService {
  struct SetConfig {
    let rackId: String
    let profileId: String
    let macro: String
    let sweep: String
    let root: String
    let index: String
    let notes: String?
  }

  static func set(config: SetConfig) throws -> String {
    let destDir = URL(fileURLWithPath: config.root, isDirectory: true).appendingPathComponent(config.rackId, isDirectory: true)
    try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
    let destPath = destDir.appendingPathComponent("\(config.macro).baseline.v1.json").path

    if FileManager.default.fileExists(atPath: destPath) {
      let bak = destPath + ".bak"
      try? FileManager.default.removeItem(atPath: bak)
      try FileManager.default.copyItem(atPath: destPath, toPath: bak)
    }
    if FileManager.default.fileExists(atPath: destPath) { try FileManager.default.removeItem(atPath: destPath) }
    try FileManager.default.copyItem(atPath: config.sweep, toPath: destPath)

    var idx = loadIndex(path: config.index)
    idx.items.removeAll { $0.rackId == config.rackId && $0.profileId == config.profileId && $0.macro == config.macro }
    idx.items.append(.init(rackId: config.rackId, profileId: config.profileId, macro: config.macro, path: destPath, notes: config.notes))
    idx.items.sort { ($0.rackId, $0.macro) < ($1.rackId, $1.macro) }
    try JSONIO.save(idx, to: URL(fileURLWithPath: config.index))

    return destPath
  }

  private static func loadIndex(path: String) -> BaselineIndexV1 {
    if FileManager.default.fileExists(atPath: path),
       let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
       let idx = try? JSONDecoder().decode(BaselineIndexV1.self, from: data) {
      return idx
    }
    return BaselineIndexV1(schemaVersion: 1, items: [])
  }
}
