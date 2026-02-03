import Foundation
import ArgumentParser

/// v7.4: fully-automated macro setting via MIDI CC + export orchestration + sonic sweep.
/// Assumes Ableton mapping: Macro -> MIDI CC (set once).
struct SonicSweepCompile: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sweep-compile",
    abstract: "Automate macro sweep: set macro via MIDI CC, export per position, then run sonic sweep."
  )

  @OptionGroup var common: CommonOptions

  @Option(name: .long) var macro: String
  @Option(name: .long, help: "Comma-separated positions (0..1).") var positions: String
  @Option(name: .long) var exportDir: String
  @Option(name: .long) var baseName: String = "BASE"
  @Option(name: .long, help: "MIDI destination name contains (e.g. 'IAC Driver' or 'Bus 1').") var midiDest: String = "IAC"
  @Option(name: .long, help: "CC number mapped to the macro (0-127).") var cc: Int
  @Option(name: .long, help: "MIDI channel 1-16 (default 1).") var channel: Int = 1
  @Option(name: .long, help: "Export chord (default CMD+SHIFT+R).") var exportChord: String = "CMD+SHIFT+R"
  @Option(name: .long, help: "Wait seconds after export (default 8).") var waitSeconds: Double = 8.0
  @Option(name: .long) var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/bass_music_sweep_defaults.v1.json")
  @Option(name: .long) var rackId: String?
  @Option(name: .long) var profileId: String?

  func run() async throws {
    let receipt = try await SonicSweepCompileService.run(config: .init(macro: macro,
                                                                        positions: positions,
                                                                        exportDir: exportDir,
                                                                        baseName: baseName,
                                                                        midiDest: midiDest,
                                                                        cc: cc,
                                                                        channel: channel,
                                                                        exportChord: exportChord,
                                                                        waitSeconds: waitSeconds,
                                                                        thresholds: thresholds,
                                                                        rackId: rackId,
                                                                        profileId: profileId,
                                                                        runsDir: common.runsDir))
    print("receipt: \(common.runsDir)/\(receipt.runId)/sonic_sweep_compile_receipt.v1.json")
    if receipt.status != "pass" { throw ExitCode(1) }
  }
}
