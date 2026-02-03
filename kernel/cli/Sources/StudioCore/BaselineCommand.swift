import Foundation
import ArgumentParser

struct Baseline: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "baseline",
    abstract: "Manage sonic baselines (v8.5).",
    subcommands: [Set.self, Get.self, List.self]
  )

  struct Set: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "set", abstract: "Set baseline for rack/profile/macro by copying a sweep receipt into canonical path and updating index.")

    @Option(name: .long) var rackId: String
    @Option(name: .long) var profileId: String
    @Option(name: .long) var macro: String
    @Option(name: .long, help: "Sweep receipt JSON path (v7.2).") var sweep: String
    @Option(name: .long, help: "Baselines root (default shared/specs/profiles/<active_profile>/sonic/baselines).") var root: String = WubDefaults.profileSpecPath("sonic/baselines")
    @Option(name: .long, help: "Baseline index path (default shared/specs/profiles/<active_profile>/sonic/baselines/baseline_index.v1.json).") var index: String = WubDefaults.profileSpecPath("sonic/baselines/baseline_index.v1.json")
    @Option(name: .long) var notes: String?

    func run() throws {
      let destDir = URL(fileURLWithPath: root, isDirectory: true).appendingPathComponent(rackId, isDirectory: true)
      try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
      let destPath = destDir.appendingPathComponent("\(macro).baseline.v1.json").path

      if FileManager.default.fileExists(atPath: destPath) {
        // backup
        let bak = destPath + ".bak"
        try? FileManager.default.removeItem(atPath: bak)
        try FileManager.default.copyItem(atPath: destPath, toPath: bak)
      }
      // overwrite copy
      if FileManager.default.fileExists(atPath: destPath) { try FileManager.default.removeItem(atPath: destPath) }
      try FileManager.default.copyItem(atPath: sweep, toPath: destPath)

      // update index
      var idx = loadIndex(path: index)
      idx.items.removeAll { $0.rackId == rackId && $0.profileId == profileId && $0.macro == macro }
      idx.items.append(.init(rackId: rackId, profileId: profileId, macro: macro, path: destPath, notes: notes))
      idx.items.sort { ($0.rackId, $0.macro) < ($1.rackId, $1.macro) }
      try JSONIO.save(idx, to: URL(fileURLWithPath: index))

      print("baseline: \(destPath)")
      print("index: \(index)")
    }

    private func loadIndex(path: String) -> BaselineIndexV1 {
      if FileManager.default.fileExists(atPath: path),
         let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
         let idx = try? JSONDecoder().decode(BaselineIndexV1.self, from: data) {
        return idx
      }
      return BaselineIndexV1(schemaVersion: 1, items: [])
    }
  }

  struct Get: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "get", abstract: "Get canonical baseline path from index for rack/profile/macro.")

    @Option(name: .long) var rackId: String
    @Option(name: .long) var profileId: String
    @Option(name: .long) var macro: String
    @Option(name: .long) var index: String = WubDefaults.profileSpecPath("sonic/baselines/baseline_index.v1.json")

    func run() throws {
      let data = try Data(contentsOf: URL(fileURLWithPath: index))
      let idx = try JSONDecoder().decode(BaselineIndexV1.self, from: data)
      if let item = idx.items.first(where: { $0.rackId == rackId && $0.profileId == profileId && $0.macro == macro }) {
        print(item.path)
      } else {
        throw ValidationError("Baseline not found in index.")
      }
    }
  }

  struct List: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list", abstract: "List baselines from index.")

    @Option(name: .long) var index: String = WubDefaults.profileSpecPath("sonic/baselines/baseline_index.v1.json")

    func run() throws {
      let data = try Data(contentsOf: URL(fileURLWithPath: index))
      let idx = try JSONDecoder().decode(BaselineIndexV1.self, from: data)
      for it in idx.items {
        print("\(it.rackId) \t \(it.profileId) \t \(it.macro) \t \(it.path)")
      }
    }
  }
}
