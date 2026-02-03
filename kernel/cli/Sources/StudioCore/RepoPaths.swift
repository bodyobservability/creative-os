import Foundation

/// Single source of truth for repo topology.
/// Paths only: no domain semantics and no execution logic.
enum RepoPaths {
  // MARK: Root resolution

  static func rootURL(fileManager: FileManager = .default,
                      env: [String: String] = ProcessInfo.processInfo.environment,
                      cwd: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)) -> URL {
    if let override = env["CREATIVE_OS_ROOT"], !override.isEmpty {
      return URL(fileURLWithPath: override, isDirectory: true)
    }

    var cur = cwd
    for _ in 0..<16 {
      let marker = cur.appendingPathComponent("shared/specs", isDirectory: true)
      if fileManager.fileExists(atPath: marker.path) { return cur }
      let parent = cur.deletingLastPathComponent()
      if parent.path == cur.path { break }
      cur = parent
    }

    return cwd
  }

  // MARK: Canonical directories

  static func kernelDir(root: URL) -> URL { root.appendingPathComponent("kernel", isDirectory: true) }
  static func operatorDir(root: URL) -> URL { root.appendingPathComponent("operator", isDirectory: true) }
  static func sharedDir(root: URL) -> URL { root.appendingPathComponent("shared", isDirectory: true) }
  static func docsDir(root: URL) -> URL { root.appendingPathComponent("docs", isDirectory: true) }
  static func runsDir(root: URL) -> URL { root.appendingPathComponent("runs", isDirectory: true) }

  static func profilesDir(root: URL) -> URL { operatorDir(root: root).appendingPathComponent("profiles", isDirectory: true) }
  static func packsDir(root: URL) -> URL { operatorDir(root: root).appendingPathComponent("packs", isDirectory: true) }
  static func notesDir(root: URL) -> URL { operatorDir(root: root).appendingPathComponent("notes", isDirectory: true) }

  static func sharedSpecsDir(root: URL) -> URL { sharedDir(root: root).appendingPathComponent("specs", isDirectory: true) }
  static func sharedProfileSpecsDir(root: URL, profileId: String) -> URL {
    sharedSpecsDir(root: root)
      .appendingPathComponent("profiles", isDirectory: true)
      .appendingPathComponent(profileId, isDirectory: true)
  }
  static func sharedContractsDir(root: URL) -> URL { sharedDir(root: root).appendingPathComponent("contracts", isDirectory: true) }

  static func operatorConfigPath(root: URL) -> URL { notesDir(root: root).appendingPathComponent("WUB_CONFIG.json") }
  static func operatorLocalConfigPath(root: URL) -> URL { notesDir(root: root).appendingPathComponent("LOCAL_CONFIG.json") }

  // MARK: Repo-relative helpers

  static func relPath(root: URL, url: URL) -> String {
    let rootStd = root.standardizedFileURL.path
    let urlStd = url.standardizedFileURL.path

    if urlStd.hasPrefix(rootStd + "/") {
      return String(urlStd.dropFirst(rootStd.count + 1))
    }

    return urlStd
  }

  static func relOrAbs(root: URL, url: URL) -> String {
    let rootStd = root.standardizedFileURL.path
    let cwdStd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true).standardizedFileURL.path
    if cwdStd == rootStd {
      return relPath(root: root, url: url)
    }
    return url.standardizedFileURL.path
  }

  // MARK: Default path strings

  static func defaultRunsDir() -> String {
    let root = rootURL()
    return relOrAbs(root: root, url: runsDir(root: root))
  }

  static func defaultChecksumsIndexDir() -> String {
    let root = rootURL()
    let dir = root.appendingPathComponent("checksums/index", isDirectory: true)
    return relOrAbs(root: root, url: dir)
  }

  static func defaultArtifactIndexPath() -> String {
    let root = rootURL()
    let path = root.appendingPathComponent("checksums/index/artifact_index.v1.json")
    return relOrAbs(root: root, url: path)
  }

  static func defaultReceiptIndexPath() -> String {
    let root = rootURL()
    let path = root.appendingPathComponent("checksums/index/receipt_index.v1.json")
    return relOrAbs(root: root, url: path)
  }

  static func defaultRegionsConfigDir() -> String {
    let root = rootURL()
    let dir = kernelDir(root: root).appendingPathComponent("cli/config", isDirectory: true)
    return relOrAbs(root: root, url: dir)
  }

  static func defaultRegionsConfigPath() -> String {
    let root = rootURL()
    let path = kernelDir(root: root).appendingPathComponent("cli/config/regions.v1.json")
    return relOrAbs(root: root, url: path)
  }

  static func defaultSubstitutionsPath() -> String {
    let root = rootURL()
    let path = sharedSpecsDir(root: root).appendingPathComponent("automation/substitutions/substitutions.v1.json")
    return relOrAbs(root: root, url: path)
  }

  static func defaultRecommendationsPath() -> String {
    let root = rootURL()
    let path = sharedSpecsDir(root: root).appendingPathComponent("automation/recommendations/recommendations.v1.json")
    return relOrAbs(root: root, url: path)
  }

  static func defaultPackSignaturesPath() -> String {
    let root = rootURL()
    let path = sharedSpecsDir(root: root).appendingPathComponent("automation/recommendations/pack_signatures.v1.json")
    return relOrAbs(root: root, url: path)
  }

  static func defaultAnchorsDir() -> String {
    let root = rootURL()
    let path = sharedSpecsDir(root: root).appendingPathComponent("automation/anchors", isDirectory: true)
    return relOrAbs(root: root, url: path)
  }

  static func defaultAnchorsPackHint() -> String {
    return defaultAnchorsDir() + "/<pack_id>"
  }

  static func defaultReleaseProfilePath(profileId: String, relative: String) -> String {
    let root = rootURL()
    let path = sharedProfileSpecsDir(root: root, profileId: profileId).appendingPathComponent(relative)
    return relOrAbs(root: root, url: path)
  }
}
