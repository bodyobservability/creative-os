import Foundation

enum DriftPlanner {
  static func recommendFixes(findings: [DriftReportV2.Finding]) -> [DriftReportV2.Fix] {
    // Group by identical fix command.
    var groups: [String: [DriftReportV2.Finding]] = [:]
    for f in findings {
      groups[f.fix, default: []].append(f)
    }

    // Sort groups by severity weight and coverage count.
    func weight(_ fs: [DriftReportV2.Finding]) -> Int {
      var w = 0
      for f in fs {
        switch f.severity {
        case "fail": w += 100
        case "warn": w += 10
        case "info": w += 1
        default: break
        }
      }
      return w
    }

    let sorted = groups.keys.sorted { a, b in
      let wa = weight(groups[a] ?? [])
      let wb = weight(groups[b] ?? [])
      if wa != wb { return wa > wb }
      return (groups[a]?.count ?? 0) > (groups[b]?.count ?? 0)
    }

    var out: [DriftReportV2.Fix] = []
    for (i, cmd) in sorted.enumerated() {
      let fs = groups[cmd] ?? []
      let covers = fs.map { $0.artifactPath }.sorted()
      let notes = "covers=\(covers.count) top_severity=\(fs.map(\.severity).sorted().last ?? "")"
      out.append(.init(id: "fix_\(i+1)", command: cmd, covers: covers, notes: notes))
    }
    return out
  }
}
