import Foundation
import ArgumentParser

struct Ready: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ready",
    abstract: "Preflight verifier: are we ARTIFACT-READY? (v1.7.14)"
  )

  @Option(name: .long, help: "Anchors pack hint used only for suggested commands.")
  var anchorsPackHint: String = RepoPaths.defaultAnchorsPackHint()

  @Option(name: .long, help: "Artifact index path.")
  var artifactIndex: String = RepoPaths.defaultArtifactIndexPath()

  @Option(name: .long, help: "Run directory to inspect for drift/export receipts (optional). Defaults to latest \(RepoPaths.defaultRunsDir())/<id>.")
  var runDir: String? = nil

  @Flag(name: .long, inversion: .prefixedNo, help: "Write JSON report to \(RepoPaths.defaultRunsDir())/<run_id>/ready_report.v1.json")
  var writeReport: Bool = true

  func run() async throws {
    let report = try ReadyService.run(config: .init(anchorsPackHint: anchorsPackHint,
                                                    artifactIndex: artifactIndex,
                                                    runDir: runDir,
                                                    writeReport: writeReport))

    print("READY CHECK (v1.7.14)")
    print("status: \(report.status.uppercased())")
    for c in report.checks {
      print("- \(c.id): \(c.status)")
    }
    if !report.recommendedCommands.isEmpty {
      print("\nRecommended next commands:")
      for c in report.recommendedCommands { print("  " + c) }
    }

    if writeReport {
      print("\nreport: \(RepoPaths.defaultRunsDir())/\(report.runId)/ready_report.v1.json")
    }

    if report.status == "not_ready" { throw ExitCode(2) }
  }
}
