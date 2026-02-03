import Foundation
import ArgumentParser

struct Voice: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "voice",
    abstract: "Voice layer utilities (print prompt cards, generate verification plans, run handshake).",
    subcommands: [Print.self, Verify.self, Run.self],
    defaultSubcommand: Print.self
  )

  struct Print: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "print", abstract: "Render a voice script as a one-page Markdown prompt card.")

    @Option(name: .long, help: "Path to voice script YAML.")
    var script: String

    @Option(name: .long, help: "Anchors pack path to embed in instructions.")
    var anchorsPack: String?

    @Option(name: .long, help: "Output Markdown path (optional).")
    var out: String?

    @Option(name: .long, help: "Display profile label (optional).")
    var display: String?

    @Option(name: .long, help: "Ableton version label (optional).")
    var ableton: String?

    @Option(name: .long, help: "Ableton theme label (optional).")
    var theme: String?

    func run() throws {
      let md = try VoicePrint.renderMarkdown(scriptPath: script,
                                            anchorsPack: anchorsPack,
                                            displayProfile: display,
                                            abletonVersion: ableton,
                                            abletonTheme: theme,
                                            outPath: out)
      if out == nil { print(md) }
    }
  }

  struct Verify: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify", abstract: "Generate a v4 verification plan from the macro ABI.")

    @Option(name: .long, help: "Path to macro ABI YAML.")
    var abi: String

    @Option(name: .long, help: "Output plan JSON path.")
    var out: String

    @Option(name: .long, help: "Enable macro-name OCR checks (requires regions 'rack.macros').")
    var macroOcr: Bool = false

    @Option(name: .long, help: "Macro label region id (default: rack.macros).")
    var macroRegion: String = "rack.macros"

    func run() throws {
      try VoiceVerify.generatePlan(abiPath: abi, outPath: out, includeMacroNameOCR: macroOcr, macroRegionId: macroRegion)
      print("Wrote plan: \(out)")
    }
  }

  struct Run: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Voice+v4 handshake: print card, wait for human compile, then sweep + apply verify, emit voice_receipt.v1.json")

    @Option(name: .long, help: "Path to voice script YAML.")
    var script: String

    @Option(name: .long, help: "Path to macro ABI YAML.")
    var abi: String

    @Option(name: .long, help: "Anchors pack path (for sweep/apply).")
    var anchorsPack: String

    @Option(name: .long, help: "Regions config path.")
    var regions: String = RepoPaths.defaultRegionsConfigPath()

    @Option(name: .long, help: "Enable macro-name OCR checks (requires regions 'rack.macros').")
    var macroOcr: Bool = false

    @Option(name: .long, help: "Macro label region id (default: rack.macros).")
    var macroRegion: String = "rack.macros"

    @Option(name: .long, help: "Run sweep with --fix first.")
    var fix: Bool = false

    func run() async throws {
      let receipt = try await VoiceService.run(config: .init(script: script,
                                                             abi: abi,
                                                             anchorsPack: anchorsPack,
                                                             regions: regions,
                                                             macroOcr: macroOcr,
                                                             macroRegion: macroRegion,
                                                             fix: fix,
                                                             runsDir: RepoPaths.defaultRunsDir()))
      print("\nvoice_receipt: runs/\(receipt.runId)/voice_receipt.v1.json")
      if receipt.status != "pass" { throw ExitCode(1) }
    }
  }
}
