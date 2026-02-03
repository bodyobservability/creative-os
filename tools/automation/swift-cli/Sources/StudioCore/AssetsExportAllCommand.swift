import Foundation
import ArgumentParser

extension Assets {
  struct ExportAll: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-all",
      abstract: "Run the full repo completeness export pipeline (racks, performance set, finishing bays, serum base, extras)."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Anchors pack passed to apply in subcommands.")
    var anchorsPack: String?

    @Flag(name: .long, help: "Overwrite existing outputs when supported.")
    var overwrite: Bool = false

    @Flag(name: .long, help: "Skip interactive prompts (uses safe defaults).")
    var nonInteractive: Bool = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    @Option(name: .long, help: "Output directory for racks export.")
    var racksOut: String = WubDefaults.packPath("ableton/racks/BASS_RACKS")

    @Option(name: .long, help: "Target path for performance set export.")
    var performanceOut: String = WubDefaults.packPath("ableton/performance-sets/BASS_PERFORMANCE_SET_v1.0.als")

    @Option(name: .long, help: "Spec file for finishing bays export.")
    var baysSpec: String = WubDefaults.profileSpecPath("assets/export/finishing_bays_export.v1.yaml")

    @Option(name: .long, help: "Target path for Serum base export.")
    var serumOut: String = "library/serum/SERUM_BASE_v1.0.fxp"

    @Option(name: .long, help: "Spec file for extra exports.")
    var extrasSpec: String = WubDefaults.profileSpecPath("assets/export/extra_exports.v1.yaml")

    @Flag(name: .long, inversion: .prefixedNo, help: "Run post-export semantic checks.")
    var postcheck: Bool = true

    @Option(name: .long, help: "Rack verify manifest path (postcheck).")
    var rackVerifyManifest: String = WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json")

    @Option(name: .long, help: "VRL mapping spec path (postcheck).")
    var vrlMapping: String = WubDefaults.profileSpecPath("voice/runtime/vrl_mapping.v1.yaml")

    func run() async throws {
      let receipt = try await AssetsService.exportAll(config: .init(anchorsPack: anchorsPack,
                                                                    overwrite: overwrite,
                                                                    nonInteractive: nonInteractive,
                                                                    preflight: preflight,
                                                                    runsDir: common.runsDir,
                                                                    regionsConfig: common.regionsConfig,
                                                                    racksOut: racksOut,
                                                                    performanceOut: performanceOut,
                                                                    baysSpec: baysSpec,
                                                                    serumOut: serumOut,
                                                                    extrasSpec: extrasSpec,
                                                                    postcheck: postcheck,
                                                                    rackVerifyManifest: rackVerifyManifest,
                                                                    vrlMapping: vrlMapping,
                                                                    force: force))
      print("receipt: \(common.runsDir)/\(receipt.runId)/assets_export_all_receipt.v1.json")
      if receipt.status == "fail" { throw ExitCode(1) }
    }
  }
}
