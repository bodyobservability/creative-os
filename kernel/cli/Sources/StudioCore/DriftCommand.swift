import Foundation
import ArgumentParser

struct Drift: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "drift",
    abstract: "Drift detection.",
    subcommands: [Check.self, Explain.self, Plan.self, Fix.self]
  )

  struct Check: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "check",
      abstract: "Check artifact drift and emit a drift report."
    )

    @Option(name: .long) var artifactIndex: String = RepoPaths.defaultArtifactIndexPath()
    @Option(name: .long) var receiptIndex: String = RepoPaths.defaultReceiptIndexPath()
    @Option(name: .long) var anchorsPackHint: String? = nil
    @Option(name: .long) var out: String? = nil

    @Option(name: .long, help: "Output format: human|json")
    var format: String = "human"

    @Option(name: .long, help: "Group output by fix command (true/false).")
    var groupByFix: Bool = true

    @Flag(name: .long, help: "Show only failures (no warn/info).")
    var onlyFail: Bool = false

    func run() throws {
      let result = try DriftService.check(config: .init(artifactIndex: artifactIndex,
                                                        receiptIndex: receiptIndex,
                                                        anchorsPackHint: anchorsPackHint,
                                                        out: out,
                                                        format: format,
                                                        groupByFix: groupByFix,
                                                        onlyFail: onlyFail))
      let report = result.report
      let outPath = result.outPath

      if format == "json" {
        print(outPath)
        if report.status == "fail" { throw ExitCode(1) }
        return
      }

      // Human output
      print("DRIFT CHECK")
      print("status: \(report.status)")
      print(report.summary)
      print("")

      if report.findings.isEmpty {
        print("No drift detected.")
      } else if groupByFix {
        for fx in report.recommendedFixes {
          // show the strongest severity among covered findings
          let covered = report.findings.filter { fx.covers.contains($0.artifactPath) }
          let top = covered.map(\.severity).contains("fail") ? "FAIL" : (covered.map(\.severity).contains("warn") ? "WARN" : "INFO")
          print("\(top)  fix: \(fx.command)")
          print("      covers: \(fx.covers.count)")
          // show up to 5 paths
          for p in fx.covers.prefix(5) {
            print("      - \(p)")
          }
          if fx.covers.count > 5 { print("      … (+\(fx.covers.count-5) more)") }
        }
      } else {
        for (i, f) in report.findings.enumerated() {
          print("\(i+1)) \(f.severity.uppercased())  \(f.title)")
          print("   why: \(f.why)")
          print("   fix: \(f.fix)")
        }
      }

      print("\nreport: \(outPath)")
      if report.status == "fail" { throw ExitCode(1) }
    }
  }

  struct Plan: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "plan",
      abstract: "Print a short remediation plan (commands only) for current drift findings."
    )

    @Option(name: .long) var artifactIndex: String = RepoPaths.defaultArtifactIndexPath()
    @Option(name: .long) var receiptIndex: String = RepoPaths.defaultReceiptIndexPath()
    @Option(name: .long) var anchorsPackHint: String? = nil

    func run() throws {
      let aidx = try JSONIO.load(ArtifactIndexV1.self, from: URL(fileURLWithPath: artifactIndex))
      let ridx = try JSONIO.load(ReceiptIndexV1.self, from: URL(fileURLWithPath: receiptIndex))
      let budgets = DriftEvaluator.Budgets(staleWarnAfterS: 24*3600, staleFailAfterS: 7*24*3600, placeholderFail: true)
      let fixes = FixCatalog(anchorsPackHint: anchorsPackHint)
      let base = DriftEvaluator.evaluate(artifactIndex: aidx, receiptIndex: ridx, budgets: budgets, suggestedFixes: fixes)

      let findingsV2: [DriftReportV2.Finding] = base.findings.map { f in
        DriftReportV2.Finding(id: f.id, severity: f.severity, kind: f.kind, artifactPath: f.artifactPath, title: f.title, why: f.why, fix: f.fix, details: f.details)
      }
      let recommended = DriftPlanner.recommendFixes(findings: findingsV2)

      if recommended.isEmpty {
        print("# No drift fixes needed.")
        return
      }

      print("# Drift remediation plan")
      for fx in recommended {
        print(fx.command)
      }
    }
  }

  struct Explain: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "explain",
      abstract: "Explain why a specific artifact is flagged by drift."
    )

    @Argument var query: String
    @Option(name: .long) var artifactIndex: String = RepoPaths.defaultArtifactIndexPath()

    func run() throws {
      let aidx = try JSONIO.load(ArtifactIndexV1.self, from: URL(fileURLWithPath: artifactIndex))
      guard let a = aidx.artifacts.first(where: { $0.artifactId == query || $0.path == query }) else {
        throw ValidationError("Artifact not found in index.")
      }

      print("ARTIFACT EXPLAIN")
      print("path: \(a.path)")
      print("kind: \(a.kind)")
      print("state: \(a.status.state)")
      print("reason: \(a.status.reason)")
      print("bytes: \(a.bytes.map(String.init) ?? "")")
      print("mtime: \(a.mtime ?? "")")
      if let ex = a.export {
        print("export_job: \(ex.job)")
        print("export_run: \(ex.runId)")
        print("export_receipt: \(ex.receiptPath)")
        print("exported_at: \(ex.exportedAt)")
      }
    }
  }
}
