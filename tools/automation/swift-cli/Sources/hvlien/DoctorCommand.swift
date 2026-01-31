import Foundation
import ArgumentParser

struct Doctor: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "doctor",
    abstract: "Run station readiness checks (regions, anchors, controllers, modal guard, Ableton liveness)."
  )

  @OptionGroup var common: CommonOptions
  @Option(name: .long, help: "Anchors pack path (optional).") var anchorsPack: String?
  @Option(name: .long, help: "Modal test mode: detect | active.") var modalTest: String = "detect"
  @Option(name: .long, parsing: .upToNextOption, help: "Required controllers (repeatable).") var requireController: [String] = []
  @Flag(name: .long, help: "Allow OCR fallback if OpenCV is not enabled.") var allowOcrFallback: Bool = false
  @Flag(name: .long, help: "Run quick fix (ESC + OCR cancel) before checks.") var fix: Bool = false

  func run() async throws {
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()
    let runDir = ctx.runDir

    let artifactsDir = runDir.appendingPathComponent("doctor", isDirectory: true)
    try FileManager.default.createDirectory(at: artifactsDir, withIntermediateDirectories: true)

    let mode = ModalTestMode(rawValue: modalTest) ?? .detect
    let context = DoctorContext(runId: ctx.runId,
                                runDir: runDir,
                                artifactsDir: artifactsDir,
                                regionsPath: common.regionsConfig,
                                anchorsPackPath: anchorsPack,
                                modalTestMode: mode,
                                requiredControllers: requireController,
                                allowOcrFallback: allowOcrFallback)

    if fix {
      let actions = await DoctorFix.run(context: context)
      for a in actions { print(a) }
    }

    let checks: [DoctorCheck] = [
      RegionsSanityCheck(),
      AbletonLivenessCheck(),
      ModalGuardCheck(),
      AnchorValidationCheck(),
      ControllersCheck()
    ]

    var entries: [DoctorCheckEntry] = []
    for c in checks {
      let res = try await c.run(context: context)
      entries.append(DoctorCheckEntry(id: res.id, status: res.status, details: res.details, artifacts: res.artifacts))
    }

    let anyFail = entries.contains { $0.status == .fail }
    let anyPass = entries.contains { $0.status == .pass }
    let status: DoctorStatus = anyFail ? .fail : (anyPass ? .pass : .skip)

    let report = DoctorReportV1(schemaVersion: 1,
                                runId: ctx.runId,
                                timestamp: context.nowISO8601(),
                                status: status,
                                checks: entries,
                                artifactsDir: "runs/\(ctx.runId)/doctor")

    try JSONIO.save(report, to: runDir.appendingPathComponent("doctor_report.v1.json"))

    DoctorSummaryPrinter.printSummary(report)
    let hints = DoctorHints.nextActions(from: report)
    if !hints.isEmpty {
      print("Next actions:")
      for h in hints { print("- \(h)") }
      print("")
    }
    if status == .pass { DoctorReadyMessage.printIfReady(report: report) }
    if status == .fail { throw ExitCode(1) }
  }
}
