import Foundation
import ArgumentParser

struct SonicDiffCommand: ParsableCommand {
  static let configuration = CommandConfiguration(commandName: "diff-sweep",
    abstract: "Compare two sonic_sweep_receipt files (baseline vs current) and emit a diff receipt.")

  @Option(name: .long) var baseline: String
  @Option(name: .long) var current: String
  @Option(name: .long) var out: String?

  func run() throws {
    let receipt = try SonicDiff.diff(baselinePath: baseline, currentPath: current)

    let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(receipt.runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let outPath = out ?? runDir.appendingPathComponent("sonic_diff_receipt.v1.json").path
    try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))

    print("status: \(receipt.status)")
    if !receipt.reasons.isEmpty {
      print("reasons:")
      for r in receipt.reasons { print(" - \(r)") }
    }
    print("receipt: \(outPath)")
    if receipt.status == "fail" { throw ExitCode(1) }
  }
}
