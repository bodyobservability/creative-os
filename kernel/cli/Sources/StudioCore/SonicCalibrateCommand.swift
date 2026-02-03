import Foundation
import ArgumentParser

/// v7.6: one-command calibration loop
/// 1) sweep-compile (sets macro via MIDI CC + exports per position)
/// 2) sonic sweep (writes receipt to known path)
/// 3) sonic tune-profile (writes tuned profile + tune receipt)
struct SonicCalibrateCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "calibrate",
    abstract: "Calibrate a macro profile: sweep-compile -> sweep receipt -> tune profile."
  )

  @OptionGroup var common: CommonOptions

  @Option(name: .long) var macro: String
  @Option(name: .long) var positions: String
  @Option(name: .long) var exportDir: String
  @Option(name: .long) var baseName: String = "BASE"
  @Option(name: .long) var midiDest: String = "IAC"
  @Option(name: .long) var cc: Int
  @Option(name: .long) var channel: Int = 1
  @Option(name: .long) var exportChord: String = "CMD+SHIFT+R"
  @Option(name: .long) var waitSeconds: Double = 8.0
  @Option(name: .long) var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/bass_music_sweep_defaults.v1.json")

  @Option(name: .long, help: "Profile YAML to tune (v6.1).") var profile: String
  @Option(name: .long, help: "Output tuned profile path (optional).") var outProfile: String?
  @Option(name: .long) var rackId: String?
  @Option(name: .long) var profileId: String?

  func run() async throws {
    let receipt = try await SonicCalibrateService.run(config: .init(macro: macro,
                                                                    positions: positions,
                                                                    exportDir: exportDir,
                                                                    baseName: baseName,
                                                                    midiDest: midiDest,
                                                                    cc: cc,
                                                                    channel: channel,
                                                                    exportChord: exportChord,
                                                                    waitSeconds: waitSeconds,
                                                                    thresholds: thresholds,
                                                                    profile: profile,
                                                                    outProfile: outProfile,
                                                                    rackId: rackId,
                                                                    profileId: profileId,
                                                                    runsDir: common.runsDir))
    print("receipt: \(common.runsDir)/\(receipt.runId)/sonic_calibrate_receipt.v1.json")
    if receipt.status != "pass" { throw ExitCode(1) }
  }
}
