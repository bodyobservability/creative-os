import ArgumentParser
import Foundation

struct AnchorsSelect: ParsableCommand {
  static let configuration = CommandConfiguration(commandName: "anchors", abstract: "Manage anchors packs")

  struct Select: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "select", abstract: "Select anchors pack and save to LOCAL_CONFIG.json")

    func run() throws {
      let repoRoot = FileManager.default.currentDirectoryPath
      var cfg = try LocalConfig.loadOrCreate(atRepoRoot: repoRoot)
      let packs = collectAnchors(repoRoot: repoRoot)
      if packs.isEmpty {
        throw ValidationError("No anchors packs found")
      }
      print("Select anchors pack:")
      for (i, p) in packs.enumerated() {
        print("  [\(i + 1)] \(p)")
      }
      print("> ", terminator: "")
      let choice = Int((readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? -1
      if choice < 1 || choice > packs.count { throw ValidationError("Invalid selection") }
      cfg.anchorsPack = packs[choice - 1]
      try cfg.save(atRepoRoot: repoRoot)
      print("Anchors pack set: \(packs[choice - 1])")
    }
  }

  static func collectAnchors(repoRoot: String) -> [String] {
    let fm = FileManager.default
    let rootURL = URL(fileURLWithPath: repoRoot, isDirectory: true)
    let roots = [
      RepoPaths.sharedSpecsDir(root: rootURL).appendingPathComponent("automation/anchors", isDirectory: true).path,
      RepoPaths.kernelDir(root: rootURL).appendingPathComponent("tools/automation/anchors", isDirectory: true).path,
      rootURL.appendingPathComponent("anchors", isDirectory: true).path,
      RepoPaths.sharedSpecsDir(root: rootURL).appendingPathComponent("anchors", isDirectory: true).path
    ]
    var found: [String] = []
    for root in roots {
      let dir = URL(fileURLWithPath: root, isDirectory: true)
      guard fm.fileExists(atPath: dir.path) else { continue }
      let items = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
      for name in items {
        let p = dir.appendingPathComponent(name, isDirectory: true)
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: p.path, isDirectory: &isDir), isDir.boolValue {
          let rel = p.path.replacingOccurrences(of: repoRoot + "/", with: "")
          found.append(rel)
        }
      }
    }
    return found.sorted()
  }
}
