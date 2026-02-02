import Foundation
import ArgumentParser

extension Assets {
  struct ExportFinishingBays: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-finishing-bays",
      abstract: "Export finishing bay Ableton sets (.als) into repo paths (batch Save As)."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Finishing bays export spec YAML.")
    var spec: String = WubDefaults.profileSpecPath("assets/export/finishing_bays_export.v1.yaml")

    @Option(name: .long, help: "Anchors pack passed to apply.")
    var anchorsPack: String?

    @Option(name: .long, help: "Minimum bytes for exported .als.")
    var minBytes: Int = 200000

    @Option(name: .long, help: "Warn if bytes below this.")
    var warnBytes: Int = 1000000

    @Flag(name: .long, help: "Overwrite existing files.")
    var overwrite: Bool = false

    @Flag(name: .long, help: "Prompt before exporting each bay (recommended).")
    var promptEach: Bool = true

    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    func run() async throws {
      let receipt = try await AssetsExportFinishingBaysService.run(config: .init(force: force,
                                                                                 spec: spec,
                                                                                 anchorsPack: anchorsPack,
                                                                                 minBytes: minBytes,
                                                                                 warnBytes: warnBytes,
                                                                                 overwrite: overwrite,
                                                                                 promptEach: promptEach,
                                                                                 preflight: preflight,
                                                                                 runsDir: common.runsDir,
                                                                                 regionsConfig: common.regionsConfig))
      print("\nreceipt: \(common.runsDir)/\(receipt.runId)/finishing_bays_export_receipt.v1.json")
      if receipt.status == "fail" { throw ExitCode(1) }
    }
  }
}
