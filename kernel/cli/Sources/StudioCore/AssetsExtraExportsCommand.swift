import Foundation
import ArgumentParser

extension Assets {
  struct ExportExtras: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-extras",
      abstract: "Export return FX racks and master safety chain presets into canonical repo paths."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Spec YAML describing extra exports.")
    var spec: String = WubDefaults.profileSpecPath("assets/export/extra_exports.v1.yaml")

    @Option(name: .long, help: "Anchors pack passed to apply.")
    var anchorsPack: String?

    @Option(name: .long) var minBytes: Int = 20000
    @Option(name: .long) var warnBytes: Int = 80000
    @Flag(name: .long) var overwrite: Bool = false
    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    func run() async throws {
      let receipt = try await AssetsExportExtrasService.run(config: .init(force: force,
                                                                          spec: spec,
                                                                          anchorsPack: anchorsPack,
                                                                          minBytes: minBytes,
                                                                          warnBytes: warnBytes,
                                                                          overwrite: overwrite,
                                                                          preflight: preflight,
                                                                          runsDir: common.runsDir,
                                                                          regionsConfig: common.regionsConfig))
      print("\nreceipt: \(common.runsDir)/\(receipt.runId)/extra_exports_receipt.v1.json")
      if receipt.status == "fail" { throw ExitCode(1) }
    }
  }
}
