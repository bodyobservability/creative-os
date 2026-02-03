import Foundation
import ArgumentParser
import CoreGraphics

struct VRL: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vrl",
    abstract: "Voice Runtime Layer tools.",
    subcommands: [Validate.self]
  )

  struct Validate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "validate",
      abstract: "Validate Ableton runtime mapping prerequisites and emit a receipt."
    )

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Path to mapping spec YAML.")
    var mapping: String = WubDefaults.profileSpecPath("voice/runtime/vrl_mapping.v1.yaml")

    @Option(name: .long, help: "Regions config path (must include tracks.list, device.chain, rack.macros).")
    var regions: String = RepoPaths.defaultRegionsConfigPath()

    @Option(name: .long, help: "Output receipt path (default: runs/<run_id>/vrl_mapping_receipt.v1.json).")
    var out: String?

    @Flag(name: .long, help: "Also dump OCR JSON+PNGs for key regions (recommended).")
    var dump: Bool = true

    func run() async throws {
      let receipt = try await VRLService.validate(config: .init(mapping: mapping,
                                                                regions: regions,
                                                                out: out,
                                                                dump: dump,
                                                                runsDir: common.runsDir))
      print("status: \(receipt.status)")
      let outPath = out ?? "\(common.runsDir)/\(receipt.runId)/vrl_mapping_receipt.v1.json"
      print("receipt: \(outPath)")
      if receipt.status == "fail" { throw ExitCode(1) }
    }
  }
}
