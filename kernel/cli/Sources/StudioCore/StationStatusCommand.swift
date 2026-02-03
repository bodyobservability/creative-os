import Foundation
import ArgumentParser

extension Station {
  struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "status",
      abstract: "Detect station state and emit station_state_report.v1.json (v1.7.16)."
    )

    @Option(name: .long, help: "Output format: human|json")
    var format: String = "human"

    @Option(name: .long, help: "Output path for JSON report (default runs/<run_id>/station_state_report.v1.json).")
    var out: String? = nil

    @Flag(name: .long, help: "Do not write report file; print only.")
    var noWriteReport: Bool = false

    @Option(name: .long, help: "Anchors pack hint (used only for evidence/reasons).")
    var anchorsPackHint: String = RepoPaths.defaultAnchorsPackHint()

    func run() async throws {
      _ = try await StationStatusService.run(config: .init(format: format,
                                                          out: out,
                                                          noWriteReport: noWriteReport,
                                                          anchorsPackHint: anchorsPackHint,
                                                          runsDir: RepoPaths.defaultRunsDir()))
    }
  }
}
