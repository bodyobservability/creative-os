import Foundation
import ArgumentParser

extension Assets {
  struct ExportSerumBase: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-serum-base",
      abstract: "Export Serum base patch to library/serum/ via Ableton/Serum UI automation."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Target output path.")
    var out: String = "library/serum/SERUM_BASE_v1.0.fxp"

    @Option(name: .long, help: "Anchors pack path passed to apply.")
    var anchorsPack: String?

    @Option(name: .long, help: "Minimum bytes for exported file.")
    var minBytes: Int = 5000

    @Option(name: .long, help: "Warn if bytes below this.")
    var warnBytes: Int = 20000

    @Flag(name: .long, help: "Overwrite existing file if present.")
    var overwrite: Bool = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    func run() async throws {
      let receipt = try await AssetsExportSerumBaseService.run(config: .init(force: force,
                                                                             out: out,
                                                                             anchorsPack: anchorsPack,
                                                                             minBytes: minBytes,
                                                                             warnBytes: warnBytes,
                                                                             overwrite: overwrite,
                                                                             preflight: preflight,
                                                                             runsDir: common.runsDir,
                                                                             regionsConfig: common.regionsConfig))
      print("receipt: \(common.runsDir)/\(receipt.runId)/serum_base_export_receipt.v1.json")
      if receipt.status == "fail" { throw ExitCode(1) }
    }
  }
}
