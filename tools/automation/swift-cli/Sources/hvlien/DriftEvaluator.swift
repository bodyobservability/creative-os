import Foundation

enum DriftEvaluator {

  struct Budgets {
    // Grace windows in seconds to avoid nagging during active work
    let staleWarnAfterS: Int   // warn if older than this
    let staleFailAfterS: Int   // fail if older than this
    let placeholderFail: Bool
  }

  static func evaluate(artifactIndex: ArtifactIndexV1,
                       receiptIndex: ReceiptIndexV1,
                       budgets: Budgets,
                       suggestedFixes: FixCatalog) -> DriftReportV1 {
    let runId = RunContext.makeRunId()
    let ts = ISO8601DateFormatter().string(from: Date())

    var findings: [DriftReportV1.Finding] = []
    var reasons: [String] = []

    for a in artifactIndex.artifacts {
      switch a.status.state {
      case "missing":
        findings.append(makeFinding(a: a, severity: "fail", kind: "missing", fix: suggestedFixes.suggestFix(for: a)))
        reasons.append("missing: \(a.path)")

      case "placeholder":
        let sev = budgets.placeholderFail ? "fail" : "warn"
        findings.append(makeFinding(a: a, severity: sev, kind: "placeholder", fix: suggestedFixes.suggestFix(for: a)))
        reasons.append("placeholder: \(a.path)")

      case "current":
        // no finding
        continue

      case "unknown":
        findings.append(makeFinding(a: a, severity: "info", kind: "unknown", fix: suggestedFixes.suggestFix(for: a)))
        reasons.append("unknown: \(a.path)")

      case "stale":
        // not emitted by v1.8.0 builder; reserved for future
        findings.append(makeFinding(a: a, severity: "warn", kind: "stale", fix: suggestedFixes.suggestFix(for: a)))
        reasons.append("stale: \(a.path)")

      default:
        continue
      }
    }

    // Sort findings by severity then kind
    findings.sort { rank($0.severity) > rank($1.severity) }

    let status: String = findings.contains(where: { $0.severity == "fail" }) ? "fail"
                     : (findings.contains(where: { $0.severity == "warn" }) ? "warn" : "pass")

    let summary = summaryText(status: status, findings: findings)

    return DriftReportV1(schemaVersion: 1, runId: runId, timestamp: ts, status: status, summary: summary, findings: findings, reasons: reasons)
  }

  private static func rank(_ s: String) -> Int {
    switch s {
    case "fail": return 3
    case "warn": return 2
    case "info": return 1
    default: return 0
    }
  }

  private static func makeFinding(a: ArtifactIndexV1.Artifact, severity: String, kind: String, fix: String) -> DriftReportV1.Finding {
    let title = "\(kind.uppercased()): \(a.path)"
    let why = a.status.reason
    let details: [String: String] = [
      "kind": a.kind,
      "bytes": a.bytes.map(String.init) ?? "",
      "mtime": a.mtime ?? "",
      "export_job": a.export?.job ?? ""
    ]
    return .init(id: a.artifactId, severity: severity, kind: kind, artifactPath: a.path, title: title, why: why, fix: fix, details: details)
  }

  private static func summaryText(status: String, findings: [DriftReportV1.Finding]) -> String {
    if findings.isEmpty { return "No drift detected." }
    let cFail = findings.filter { $0.severity == "fail" }.count
    let cWarn = findings.filter { $0.severity == "warn" }.count
    let cInfo = findings.filter { $0.severity == "info" }.count
    return "status=\(status) findings: fail=\(cFail) warn=\(cWarn) info=\(cInfo)"
  }
}
