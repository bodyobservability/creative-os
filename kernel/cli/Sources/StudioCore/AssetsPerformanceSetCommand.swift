import Foundation
import ArgumentParser

extension Assets {
  struct ExportPerformanceSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-performance-set",
      abstract: "Export the currently open Ableton performance set (.als) into the repo path using Save As automation."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Target output path (repo-relative or absolute).")
    var out: String = WubDefaults.packPath("ableton/performance-sets/BASS_PERFORMANCE_SET_v1.0.als")

    @Option(name: .long, help: "Anchors pack path passed to apply.")
    var anchorsPack: String?

    @Option(name: .long, help: "Minimum bytes for exported .als.")
    var minBytes: Int = 200000

    @Option(name: .long, help: "Warn if bytes below this.")
    var warnBytes: Int = 1000000

    @Flag(name: .long, help: "Do not run apply; only generate plan.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Overwrite existing file if present.")
    var overwrite: Bool = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    func run() async throws {
      let receipt = try await AssetsExportPerformanceSetService.run(config: .init(force: force,
                                                                                  out: out,
                                                                                  anchorsPack: anchorsPack,
                                                                                  minBytes: minBytes,
                                                                                  warnBytes: warnBytes,
                                                                                  dryRun: dryRun,
                                                                                  overwrite: overwrite,
                                                                                  preflight: preflight,
                                                                                  runsDir: common.runsDir,
                                                                                  regionsConfig: common.regionsConfig))
      if receipt.status == "skip" { return }
      print("receipt: \(common.runsDir)/\(receipt.runId)/performance_set_export_receipt.v1.json")
      if receipt.status == "fail" { throw ExitCode(1) }
    }
  }
}
