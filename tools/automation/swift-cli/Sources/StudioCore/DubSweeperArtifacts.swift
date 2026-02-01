import Foundation
struct DubSweeperArtifacts {
  let baseDir: URL
  init(baseDir: URL) { self.baseDir = baseDir }
  func dir(for checkId: String) -> URL { baseDir.appendingPathComponent(checkId, isDirectory: true) }
  func ensureDir(_ url: URL) throws { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
  func path(_ checkId: String, _ filename: String) -> URL { dir(for: checkId).appendingPathComponent(filename) }
  func rel(_ checkId: String, _ filename: String) -> String { "sweeper/\(checkId)/\(filename)" }
}
