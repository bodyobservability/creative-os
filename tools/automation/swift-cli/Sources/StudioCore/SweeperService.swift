import Foundation

struct SweeperService {
  struct Config {
    let anchorsPack: String?
    let modalTest: String
    let requiredControllers: [String]
    let allowOcrFallback: Bool
    let fix: Bool
    let regionsConfig: String
    let runsDir: String
  }

  static func run(config: Config) async throws -> CreativeOS.ServiceResult {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let artifactsDir = runDir.appendingPathComponent("sweeper", isDirectory: true)
    try FileManager.default.createDirectory(at: artifactsDir, withIntermediateDirectories: true)

    let mode = ModalTestMode(rawValue: config.modalTest) ?? .detect
    let context = DubSweeperContext(runId: runId,
                                    runDir: runDir,
                                    artifactsDir: artifactsDir,
                                    regionsPath: config.regionsConfig,
                                    anchorsPackPath: config.anchorsPack,
                                    modalTestMode: mode,
                                    requiredControllers: config.requiredControllers,
                                    allowOcrFallback: config.allowOcrFallback)

    if config.fix {
      _ = await DubSweeperFix.run(context: context)
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
    if config.fix {
      safeSteps.append(DubSweeperStep(id: "auto_fix_modal", description: "ESC + OCR cancel modal cleanup"))
    }

    let baseReport = DubSweeperReportV1(schemaVersion: 1,
                                        runId: runId,
                                        timestamp: context.nowISO8601(),
                                        status: status,
                                        checks: entries,
                                        safeSteps: safeSteps,
                                        manualSteps: [],
                                        artifactsDir: "runs/\(runId)/sweeper")

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

    let checkResults = CreativeOSBridge.checkResults(from: report, agentId: "sweeper")
    var planSteps: [CreativeOS.PlanStep] = []
    for step in report.safeSteps {
      planSteps.append(CreativeOS.PlanStep(id: step.id,
                                          agent: "sweeper",
                                          type: .manualRequired,
                                          description: step.description,
                                          effects: [],
                                          idempotent: true,
                                          manualReason: "sweep_safe"))
    }
    for step in report.manualSteps {
      planSteps.append(CreativeOS.PlanStep(id: step.id,
                                          agent: "sweeper",
                                          type: .manualRequired,
                                          description: step.description,
                                          effects: [],
                                          idempotent: true,
                                          manualReason: "sweep_manual"))
    }

    return CreativeOS.ServiceResult(observed: CreativeOS.ObservedStateSlice(agentId: "sweeper", data: nil, raw: nil),
                                    checks: checkResults,
                                    steps: planSteps)
  }
}
