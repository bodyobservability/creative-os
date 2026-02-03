import Foundation
import ArgumentParser

extension Drift {
  struct Fix: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "fix",
      abstract: "Execute the drift remediation plan with guarded prompts and emit a fix receipt."
    )

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long) var artifactIndex: String = "checksums/index/artifact_index.v1.json"
    @Option(name: .long) var receiptIndex: String = "checksums/index/receipt_index.v1.json"
    @Option(name: .long) var anchorsPackHint: String = RepoPaths.defaultAnchorsPackHint()

    @Flag(name: .long, help: "Skip per-command prompts; still requires one final confirmation.")
    var yes: Bool = false

    @Flag(name: .long, help: "Print commands that would run, but do not execute.")
    var dryRun: Bool = false

    @Option(name: .long, help: "Output receipt path (default runs/<run_id>/drift_fix_receipt.v1.json).")
    var out: String?

    func run() async throws {
      let receipt = try await DriftFixService.run(config: .init(force: force,
                                                                artifactIndex: artifactIndex,
                                                                receiptIndex: receiptIndex,
                                                                anchorsPackHint: anchorsPackHint,
                                                                yes: yes,
                                                                dryRun: dryRun,
                                                                out: out,
                                                                runsDir: RepoPaths.defaultRunsDir()))
      if receipt.status == "fail" { throw ExitCode(1) }
    }
  }
}
