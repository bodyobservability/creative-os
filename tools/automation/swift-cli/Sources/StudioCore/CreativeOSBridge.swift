import Foundation

enum CreativeOSBridge {
  // Mapping tables from legacy report enums/strings to CreativeOS enums.
  static let sweeperStatusMap: [DubSweeperStatus: CreativeOS.CheckSeverity] = [
    .pass: .pass,
    .fail: .fail,
    .skip: .warn
  ]

  static let readyCheckStatusMap: [String: CreativeOS.CheckSeverity] = [
    "pass": .pass,
    "warn": .warn,
    "fail": .fail,
    "skip": .warn
  ]

  static let driftFindingSeverityMap: [String: CreativeOS.CheckSeverity] = [
    "fail": .fail,
    "warn": .warn,
    "info": .warn,
    "pass": .pass
  ]

  static let driftFindingCategoryMap: [String: CreativeOS.CheckCategory] = [
    "missing": .filesystem,
    "placeholder": .filesystem,
    "stale": .filesystem,
    "unknown": .filesystem
  ]

  static func checkResults(from report: DubSweeperReportV1, agentId: String = "sweeper") -> [CreativeOS.CheckResult] {
    report.checks.map { entry in
      let severity = sweeperStatusMap[entry.status] ?? .warn
      let evidence = entry.artifacts.enumerated().map { (idx, path) in
        CreativeOS.EvidenceItem(id: "artifact_\(idx + 1)", kind: "artifact_path", path: path, details: nil)
      }
      return CreativeOS.CheckResult(id: entry.id,
                                    agent: agentId,
                                    severity: severity,
                                    category: .runtime,
                                    observed: jsonObject(entry.details),
                                    expected: nil,
                                    evidence: evidence,
                                    suggestedActions: [])
    }
  }

  static func checkResults(from report: ReadyReportV1, agentId: String = "ready") -> [CreativeOS.CheckResult] {
    report.checks.map { entry in
      let severity = readyCheckStatusMap[entry.status] ?? .warn
      return CreativeOS.CheckResult(id: entry.id,
                                    agent: agentId,
                                    severity: severity,
                                    category: .runtime,
                                    observed: jsonObject(entry.details),
                                    expected: nil,
                                    evidence: [],
                                    suggestedActions: [])
    }
  }

  static func planSteps(from report: ReadyReportV1, agentId: String = "ready") -> [CreativeOS.PlanStep] {
    report.recommendedCommands.enumerated().map { (idx, command) in
      CreativeOS.PlanStep(id: "ready_command_\(idx + 1)",
                          agent: agentId,
                          type: .manualRequired,
                          description: "Run: \(command)",
                          effects: [CreativeOS.Effect(id: "command_\(idx + 1)", kind: .process, target: command, description: "Run command")],
                          idempotent: true,
                          manualReason: "recommended_command")
    }
  }

  static func checkResults(from report: DriftReportV2, agentId: String = "drift") -> [CreativeOS.CheckResult] {
    report.findings.map { finding in
      let severity = driftFindingSeverityMap[finding.severity] ?? .warn
      let category = driftFindingCategoryMap[finding.kind] ?? .filesystem
      var evidence: [CreativeOS.EvidenceItem] = [
        CreativeOS.EvidenceItem(id: "artifact_path", kind: "artifact_path", path: finding.artifactPath, details: nil)
      ]
      if let details = finding.details {
        evidence.append(CreativeOS.EvidenceItem(id: "finding_details", kind: "details", path: nil, details: jsonObject(details)))
      }
      return CreativeOS.CheckResult(id: finding.id,
                                    agent: agentId,
                                    severity: severity,
                                    category: category,
                                    observed: jsonObject([
                                      "kind": finding.kind,
                                      "title": finding.title,
                                      "why": finding.why,
                                      "fix": finding.fix
                                    ]),
                                    expected: nil,
                                    evidence: evidence,
                                    suggestedActions: [])
    }
  }

  static func planSteps(from report: DriftReportV2, agentId: String = "drift") -> [CreativeOS.PlanStep] {
    report.recommendedFixes.enumerated().map { (idx, fix) in
      CreativeOS.PlanStep(id: fix.id,
                          agent: agentId,
                          type: .manualRequired,
                          description: "Run: \(fix.command)",
                          effects: [CreativeOS.Effect(id: "fix_command_\(idx + 1)", kind: .process, target: fix.command, description: fix.notes)],
                          idempotent: true,
                          manualReason: "recommended_fix")
    }
  }

  private static func jsonObject(_ details: [String: String]) -> CreativeOS.JSONValue? {
    if details.isEmpty { return nil }
    return .object(details.mapValues { .string($0) })
  }
}
