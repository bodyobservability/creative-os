import Foundation
import ArgumentParser
import CoreGraphics

struct VRL: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vrl",
    abstract: "Voice Runtime Layer tools (v9.x).",
    subcommands: [Validate.self]
  )

  struct Validate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "validate",
      abstract: "Validate v9.3 Ableton runtime mapping prerequisites and emit a receipt (v9.4)."
    )

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Path to v9.3 mapping spec YAML.")
    var mapping: String = WubDefaults.profileSpecPath("voice_runtime/v9_3_ableton_mapping.v1.yaml")

    @Option(name: .long, help: "Regions config path (must include tracks.list, device.chain, rack.macros).")
    var regions: String = "tools/automation/swift-cli/config/regions.v1.json"

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
