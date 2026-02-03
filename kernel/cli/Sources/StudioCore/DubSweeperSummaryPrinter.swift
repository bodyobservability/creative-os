import Foundation

enum DubSweeperSummaryPrinter {
  static func printSummary(_ report: DubSweeperReportV1) {
    print("\n== WUB sweep ==")
    print("run: \(report.runId)")
    print("status: \(report.status.rawValue.uppercased())")
    print("artifacts: \(report.artifactsDir)\n")
    print("safe steps: \(report.safeSteps.count)")
    print("manual steps: \(report.manualSteps.count)\n")
    for c in report.checks {
      print("\(badge(c.status)) \(c.id)")
      let keys = ["missing","failed","missing_required","reason","hint","mode","modal","pack"]
      for k in keys { if let v = c.details[k], !v.isEmpty { print("    \(k): \(v)") } }
    }
    print("")
  }

  private static func badge(_ s: DubSweeperStatus) -> String {
    switch s {
    case .pass: return "[PASS]"
    case .fail: return "[FAIL]"
    case .skip: return "[SKIP]"
    }
  }
}
