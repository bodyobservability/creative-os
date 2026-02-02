import Foundation
import ArgumentParser

struct Rack: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "rack",
    abstract: "Rack pack tools (verify + recommend).",
    subcommands: [Verify.self, Recommend.self]
  )

  struct Verify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify",
      abstract: "Generate a v4 plan to verify racks + macro labels, optionally run apply and emit a rack compliance receipt.")

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Path to rack_pack_manifest.v1.json")
    var manifest: String

    @Option(name: .long, help: "Macro label region id (default: rack.macros).")
    var macroRegion: String = "rack.macros"

    @Flag(name: .long, help: "Execute the generated plan via wub apply.")
    var runApply: Bool = true

    @Option(name: .long, help: "Anchors pack path (passed to apply).")
    var anchorsPack: String?

    func run() async throws {
      let receipt = try await RackVerifyService.verify(config: .init(manifest: manifest,
                                                                     macroRegion: macroRegion,
                                                                     runApply: runApply,
                                                                     anchorsPack: anchorsPack,
                                                                     runsDir: common.runsDir))
      print("plan: \(receipt.planPath)")
      print("receipt: \(common.runsDir)/\(receipt.runId)/rack_receipt.v1.json")
      if receipt.status != "pass" { throw ExitCode(1) }
    }
  }

  struct Recommend: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "recommend",
      abstract: "Recommend installs/substitutes based on missing rack dependencies using inventory + recommendations mapping.")

    @OptionGroup var common: CommonOptions

    @Option(name: .long) var manifest: String
    @Option(name: .long) var inventory: String
    @Option(name: .long, help: "Recommendations mapping JSON (optional).") var recommendations: String = WubDefaults.profileSpecPath("library/recommendations/bass_music.v1.json")
    @Option(name: .long, help: "Output path (default: stdout).") var out: String?

    func run() throws {
      let mf = try JSONDecoder().decode(RackPackManifestV1.self, from: Data(contentsOf: URL(fileURLWithPath: manifest)))
      let inv = try JSONIO.load(InventoryDoc.self, from: URL(fileURLWithPath: inventory))
      let recs = RackRecommend.recommend(manifest: mf, inventory: inv, recsPath: recommendations)
      let data = try JSONEncoder().encode(recs)
      if let out = out {
        try data.write(to: URL(fileURLWithPath: out))
        print("Wrote: \(out)")
      } else {
        print(String(data: data, encoding: .utf8) ?? "")
      }
    }
  }
}
