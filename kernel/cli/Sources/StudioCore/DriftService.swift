import Foundation

struct DriftService {
  struct Config {
    let artifactIndex: String
    let receiptIndex: String
    let anchorsPackHint: String?
    let out: String?
    let format: String
    let groupByFix: Bool
    let onlyFail: Bool
  }

  static func check(config: Config) throws -> (report: DriftReportV2, outPath: String) {
    let aidx = try JSONIO.load(ArtifactIndexV1.self, from: URL(fileURLWithPath: config.artifactIndex))
    let ridx = try JSONIO.load(ReceiptIndexV1.self, from: URL(fileURLWithPath: config.receiptIndex))

    let budgets = DriftEvaluator.Budgets(staleWarnAfterS: 24*3600, staleFailAfterS: 7*24*3600, placeholderFail: true)
    let fixes = FixCatalog(anchorsPackHint: config.anchorsPackHint)

    let base = DriftEvaluator.evaluate(artifactIndex: aidx, receiptIndex: ridx, budgets: budgets, suggestedFixes: fixes)

    let findingsV2: [DriftReportV2.Finding] = base.findings.map { f in
      DriftReportV2.Finding(id: f.id,
                            severity: f.severity,
                            kind: f.kind,
                            artifactPath: f.artifactPath,
                            title: f.title,
                            why: f.why,
                            fix: f.fix,
                            details: f.details)
    }

    let filtered = findingsV2.filter { f in
      if config.onlyFail { return f.severity == "fail" }
      return true
    }

    let recommended = DriftPlanner.recommendFixes(findings: findingsV2)

    let runId = RunContext.makeRunId()
    let ts = ISO8601DateFormatter().string(from: Date())
    let status: String = filtered.contains(where: { $0.severity == "fail" }) ? "fail"
                     : (filtered.contains(where: { $0.severity == "warn" }) ? "warn" : "pass")
    let summary = "status=\(status) findings=\(filtered.count) fixes=\(recommended.count)"

    let report = DriftReportV2(schemaVersion: 2,
                               runId: runId,
                               timestamp: ts,
                               status: status,
                               summary: summary,
                               findings: filtered,
                               reasons: base.reasons,
                               recommendedFixes: recommended)

    let runDir = URL(fileURLWithPath: RepoPaths.defaultRunsDir()).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let outPath = config.out ?? runDir.appendingPathComponent("drift_report.v2.json").path
    try JSONIO.save(report, to: URL(fileURLWithPath: outPath))

    return (report, outPath)
  }
}
