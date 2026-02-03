import Foundation
import ArgumentParser

/// v7.3: semi-automated macro sweep runner.
/// - Prompts operator to set macro position (via controller or voice)
/// - Automates export prompt + file naming best-effort (expects Ableton export shortcut configured)
/// - Runs `wub sonic sweep` over the resulting folder
struct SonicSweepRun: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sweep-run",
    abstract: "Semi-automate macro sweeps: prompt to set macro position, export clip, then run sonic sweep."
  )

  @OptionGroup var common: CommonOptions

  @Option(name: .long, help: "Macro name (e.g. Width, Energy).")
  var macro: String

  @Option(name: .long, help: "Comma-separated positions (e.g. 0,0.25,0.5,0.75,1).")
  var positions: String

  @Option(name: .long, help: "Directory where exported audio files will land (must already be selected in Ableton save sheet).")
  var exportDir: String

  @Option(name: .long, help: "Base filename prefix for exports.")
  var baseName: String = "BASE"

  @Option(name: .long, help: "Rack id for attribution.")
  var rackId: String?

  @Option(name: .long, help: "Profile id for attribution.")
  var profileId: String?

  @Option(name: .long, help: "Export shortcut chord (default CMD+SHIFT+R). Remap if needed.")
  var exportChord: String = "CMD+SHIFT+R"

  @Option(name: .long, help: "Seconds to wait after triggering export (default 8). Increase for slower renders.")
  var waitSeconds: Double = 8.0

  @Option(name: .long, help: "Thresholds JSON for sweep evaluation.")
  var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/bass_music_sweep_defaults.v1.json")

  func run() async throws {
    try await SonicSweepRunService.run(config: .init(macro: macro,
                                                     positions: positions,
                                                     exportDir: exportDir,
                                                     baseName: baseName,
                                                     rackId: rackId,
                                                     profileId: profileId,
                                                     exportChord: exportChord,
                                                     waitSeconds: waitSeconds,
                                                     thresholds: thresholds,
                                                     runsDir: common.runsDir))
  }
}
