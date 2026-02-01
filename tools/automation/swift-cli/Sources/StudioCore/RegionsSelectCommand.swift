import Foundation
import ArgumentParser
struct RegionsSelect: ParsableCommand {
  static let configuration = CommandConfiguration(commandName: "regions-select", abstract: "Activate regions profile as regions.v1.json")
  @Option(name: .long) var display: String
  @Option(name: .long) var configDir: String = "tools/automation/swift-cli/config"
  func run() throws {
    let dir = URL(fileURLWithPath: configDir, isDirectory: true)
    let srcName: String
    switch display.lowercased() {
    case "2560x1440": srcName = "regions.2560x1440.v1.json"
    case "5k-morespace": srcName = "regions.5120x2880.morespace.v1.json"
    default: throw ValidationError("Unknown display \(display)")
    }
    let src = dir.appendingPathComponent(srcName)
    let dst = dir.appendingPathComponent("regions.v1.json")
    guard FileManager.default.fileExists(atPath: src.path) else { throw ValidationError("Missing source file: \(src.path)") }
    if FileManager.default.fileExists(atPath: dst.path) {
      let ts = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
      let bak = dir.appendingPathComponent("regions.v1.json.bak-\(ts)")
      try FileManager.default.copyItem(at: dst, to: bak)
    }
    if FileManager.default.fileExists(atPath: dst.path) { try FileManager.default.removeItem(at: dst) }
    try FileManager.default.copyItem(at: src, to: dst)
    print("Activated \(srcName) → regions.v1.json")
  }
}
