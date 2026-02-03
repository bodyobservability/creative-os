import Foundation
import ArgumentParser

extension Rack {
  struct Install: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install",
      abstract: "Instantiate racks from the manifest into target tracks by searching Ableton Browser and inserting. Emits rack_install_receipt.")

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Path to rack_pack_manifest.v1.json")
    var manifest: String

    @Option(name: .long, help: "Macro label region id (default: rack.macros)")
    var macroRegion: String = "rack.macros"

    @Option(name: .long, help: "Anchors pack path (passed to apply)")
    var anchorsPack: String?

    @Flag(name: .long, help: "Allow CGEvent fallback during apply (otherwise rely on Teensy default).")
    var allowCgevent: Bool = false

    func run() async throws {
      let receipt = try await RackInstallService.install(config: .init(manifest: manifest,
                                                                       macroRegion: macroRegion,
                                                                       anchorsPack: anchorsPack,
                                                                       allowCgevent: allowCgevent,
                                                                       runsDir: common.runsDir))
      print("plan: \(receipt.planPath)")
      print("receipt: \(common.runsDir)/\(receipt.runId)/rack_install_receipt.v1.json")
      if receipt.status != "pass" { throw ExitCode(1) }
    }
  }
}
