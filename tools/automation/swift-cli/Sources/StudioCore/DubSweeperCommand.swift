import Foundation
import ArgumentParser

struct DubSweeper: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sweep-legacy",
    abstract: "Run a maintenance sweep (legacy)."
  )

  @OptionGroup var common: CommonOptions
  @Option(name: .long, help: "Anchors pack path (optional).") var anchorsPack: String?
  @Option(name: .long, help: "Modal test mode: detect | active.") var modalTest: String = "detect"
  @Option(name: .long, parsing: .upToNextOption, help: "Required controllers (repeatable).") var requireController: [String] = []
  @Flag(name: .long, help: "Allow OCR fallback if OpenCV is not enabled.") var allowOcrFallback: Bool = false
  @Flag(name: .long, help: "Run quick fix (ESC + OCR cancel) before checks.") var fix: Bool = false
  @Flag(name: .long, help: "Output JSON.") var json: Bool = false

  func run() async throws {
    let serviceConfig = SweeperService.Config(anchorsPack: anchorsPack,
                                             modalTest: modalTest,
                                             requiredControllers: requireController,
                                             allowOcrFallback: allowOcrFallback,
                                             fix: fix,
                                             regionsConfig: common.regionsConfig,
                                             runsDir: common.runsDir)
    let result = try await SweeperService.run(config: serviceConfig)

    let reportPath = latestReportPath(in: common.runsDir)
    if json {
      if let reportPath,
         let report = try? JSONIO.load(DubSweeperReportV1.self, from: URL(fileURLWithPath: reportPath)) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try enc.encode(report)
        if let out = String(data: data, encoding: .utf8) { print(out) }
      }
      return
    }

    if let reportPath,
       let report = try? JSONIO.load(DubSweeperReportV1.self, from: URL(fileURLWithPath: reportPath)) {
      DubSweeperSummaryPrinter.printSummary(report)
      let hints = DubSweeperHints.nextActions(from: report)
      if !hints.isEmpty {
        print("Next actions:")
        for h in hints { print("- \(h)") }
        print("")
      }
      if report.status == .pass { DubSweeperReadyMessage.printIfReady(report: report) }
      if report.status == .fail { throw ExitCode(1) }
    }
    _ = result
  }

  private func latestReportPath(in runsDir: String) -> String? {
    let fm = FileManager.default
    guard fm.fileExists(atPath: runsDir) else { return nil }
    guard let entries = try? fm.contentsOfDirectory(atPath: runsDir) else { return nil }
    let dirs = entries.sorted().reversed()
    for name in dirs {
      let path = "\(runsDir)/\(name)"
      var isDir: ObjCBool = false
      if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
        let report = "\(path)/sweeper_report.v1.json"
        if fm.fileExists(atPath: report) { return report }
      }
    }
    return nil
  }
}
