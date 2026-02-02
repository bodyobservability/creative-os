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
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()
    let runDir = ctx.runDir

    let artifactsDir = runDir.appendingPathComponent("sweeper", isDirectory: true)
    try FileManager.default.createDirectory(at: artifactsDir, withIntermediateDirectories: true)

    let mode = ModalTestMode(rawValue: modalTest) ?? .detect
    let context = DubSweeperContext(runId: ctx.runId,
                                runDir: runDir,
                                artifactsDir: artifactsDir,
                                regionsPath: common.regionsConfig,
                                anchorsPackPath: anchorsPack,
                                modalTestMode: mode,
                                requiredControllers: requireController,
                                allowOcrFallback: allowOcrFallback)

    if fix {
      let actions = await DubSweeperFix.run(context: context)
      for a in actions { print(a) }
    }

    let checks: [DubSweeperCheck] = [
      RegionsSanityCheck(),
      AbletonLivenessCheck(),
      ModalGuardCheck(),
      AnchorValidationCheck(),
      ControllersCheck()
    ]

    var entries: [DubSweeperCheckEntry] = []
    for c in checks {
      let res = try await c.run(context: context)
      entries.append(DubSweeperCheckEntry(id: res.id, status: res.status, details: res.details, artifacts: res.artifacts))
    }

    let anyFail = entries.contains { $0.status == .fail }
    let anyPass = entries.contains { $0.status == .pass }
    let status: DubSweeperStatus = anyFail ? .fail : (anyPass ? .pass : .skip)

    var safeSteps: [DubSweeperStep] = []
    if fix {
      safeSteps.append(DubSweeperStep(id: "auto_fix_modal", description: "ESC + OCR cancel modal cleanup"))
    }

    let baseReport = DubSweeperReportV1(schemaVersion: 1,
                                         runId: ctx.runId,
                                         timestamp: context.nowISO8601(),
                                         status: status,
                                         checks: entries,
                                         safeSteps: safeSteps,
                                         manualSteps: [],
                                         artifactsDir: "runs/\(ctx.runId)/sweeper")

    let hints = DubSweeperHints.nextActions(from: baseReport)
    let manualSteps = hints.enumerated().map { DubSweeperStep(id: "manual_\($0.offset + 1)", description: $0.element) }

    let report = DubSweeperReportV1(schemaVersion: 1,
                                     runId: baseReport.runId,
                                     timestamp: baseReport.timestamp,
                                     status: baseReport.status,
                                     checks: baseReport.checks,
                                     safeSteps: baseReport.safeSteps,
                                     manualSteps: manualSteps,
                                     artifactsDir: baseReport.artifactsDir)

    try JSONIO.save(report, to: runDir.appendingPathComponent("sweeper_report.v1.json"))

    if json {
      let enc = JSONEncoder()
      enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
      let data = try enc.encode(report)
      if let out = String(data: data, encoding: .utf8) { print(out) }
      return
    }

    DubSweeperSummaryPrinter.printSummary(report)
    if !hints.isEmpty {
      print("Next actions:")
      for h in hints { print("- \(h)") }
      print("")
    }
    if status == .pass { DubSweeperReadyMessage.printIfReady(report: report) }
    if status == .fail { throw ExitCode(1) }
  }
}
