import Foundation
import ArgumentParser

struct Assets: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "assets",
    abstract: "Asset export pipeline (v9.5).",
    subcommands: [
      ExportPreflight.self,
      ExportRacks.self,
      ExportPerformanceSet.self,
      ExportFinishingBays.self,
      ExportSerumBase.self,
      ExportExtras.self,
      ExportAll.self
    ]
  )

  struct ExportRacks: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-racks",
      abstract: "Export Ableton rack presets (.adg) into a canonical repo folder using v4 apply automation."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Rack pack manifest JSON.")
    var manifest: String = WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json")

    @Option(name: .long, help: "Output directory for exported racks.")
    var outDir: String = WubDefaults.packPath("ableton/racks/BASS_RACKS_v1.0")

    @Option(name: .long, help: "Anchors pack path passed to apply.")
    var anchorsPack: String?

    @Option(name: .long, help: "Minimum bytes for exported rack file.")
    var minBytes: Int = 20000

    @Option(name: .long, help: "Warn if bytes below this.")
    var warnBytes: Int = 80000

    @Option(name: .long, help: "Overwrite policy: ask|always|never")
    var overwrite: String = "ask"

    @Flag(name: .long, help: "Do not run apply; only generate plans and print targets.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Interactive prompts (recommended).")
    var interactive: Bool = true

    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    func run() async throws {
      let receipt = try await AssetsExportRacksService.run(config: .init(force: force,
                                                                          manifest: manifest,
                                                                          outDir: outDir,
                                                                          anchorsPack: anchorsPack,
                                                                          minBytes: minBytes,
                                                                          warnBytes: warnBytes,
                                                                          overwrite: overwrite,
                                                                          dryRun: dryRun,
                                                                          interactive: interactive,
                                                                          preflight: preflight,
                                                                          runsDir: common.runsDir,
                                                                          regionsConfig: common.regionsConfig))
      print("\nreceipt: \(common.runsDir)/\(receipt.runId)/racks_export_receipt.v1.json")
      if receipt.status == "fail" { throw ExitCode(1) }
    }
  }
}
