import Foundation

struct LocalConfig: Codable {
  var anchorsPack: String?
  var firstRunCompleted: Bool?
  var artifactExportsCompleted: Bool?

  static func path(atRepoRoot root: String) -> String {
    let rootURL = URL(fileURLWithPath: root, isDirectory: true)
    return RepoPaths.operatorLocalConfigPath(root: rootURL).path
  }

  static func loadOrCreate(atRepoRoot root: String) throws -> LocalConfig {
    let p = path(atRepoRoot: root)
    if FileManager.default.fileExists(atPath: p) {
      let data = try Data(contentsOf: URL(fileURLWithPath: p))
      return try JSONDecoder().decode(LocalConfig.self, from: data)
    }
    // create default config (but do not force anchorsPack)
    let cfg = LocalConfig(anchorsPack: nil, firstRunCompleted: false, artifactExportsCompleted: false)
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

  // MARK: anchor pack auto-detection (best-effort)
  /// Finds the newest anchor pack directory under common repo locations.
  /// Returns a repo-relative path if possible, else absolute.
  static func autoDetectAnchorsPack(repoRoot: String) -> String? {
    let fm = FileManager.default

    let rootURL = URL(fileURLWithPath: repoRoot, isDirectory: true)
    // Candidate parent directories in priority order
    let candidates = [
      RepoPaths.sharedSpecsDir(root: rootURL).appendingPathComponent("automation/anchors", isDirectory: true),
      RepoPaths.kernelDir(root: rootURL).appendingPathComponent("tools/automation/anchors", isDirectory: true),
      rootURL.appendingPathComponent("anchors", isDirectory: true),
      RepoPaths.sharedSpecsDir(root: rootURL).appendingPathComponent("anchors", isDirectory: true)
    ]

    var bestURL: URL? = nil
    var bestDate: Date = .distantPast

    for parent in candidates {
      guard fm.fileExists(atPath: parent.path) else { continue }
      guard let children = try? fm.contentsOfDirectory(at: parent, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey], options: [.skipsHiddenFiles]) else { continue }
      for c in children {
        let rv = try? c.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey])
        guard rv?.isDirectory == true else { continue }

        if !looksLikeAnchorPack(dir: c) { continue }

        let dt = rv?.contentModificationDate ?? Date.distantPast
        if dt > bestDate {
          bestDate = dt
          bestURL = c
        }
      }
    }

    guard let chosen = bestURL else { return nil }

    let rootStd = URL(fileURLWithPath: repoRoot).standardizedFileURL
    let std = chosen.standardizedFileURL
    if std.path.hasPrefix(rootStd.path + "/") {
      let rel = String(std.path.dropFirst(rootStd.path.count + 1))
      return rel
    }
    return chosen.path
  }

  private static func looksLikeAnchorPack(dir: URL) -> Bool {
    let fm = FileManager.default
    let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
    if names.contains("anchors.json") || names.contains("manifest.json") || names.contains("anchors.manifest.json") {
      return true
    }
    for n in names {
      let l = n.lowercased()
      if l.hasSuffix(".png") || l.hasSuffix(".jpg") || l.hasSuffix(".jpeg") { return true }
    }
    for n in names {
      let p = dir.appendingPathComponent(n, isDirectory: true)
      var isDir: ObjCBool = false
      if fm.fileExists(atPath: p.path, isDirectory: &isDir), isDir.boolValue {
        let inner = (try? fm.contentsOfDirectory(atPath: p.path)) ?? []
        for x in inner {
          let l = x.lowercased()
          if l.hasSuffix(".png") || l.hasSuffix(".jpg") || l.hasSuffix(".jpeg") { return true }
        }
      }
    }
    return false
  }
}
