import Foundation
import ArgumentParser

struct Pipeline: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "pipeline",
    abstract: "Release pipeline orchestration (v8.6).",
    subcommands: [CutProfile.self]
  )

  struct CutProfile: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "cut-profile",
      abstract: "One-command release cut: calibrate -> (optional baseline set) -> promote-profile."
    )

    @Option(name: .long, help: "Dev/tuned profile YAML (candidate).")
    var profileDev: String

    @Option(name: .long, help: "Rack id.")
    var rackId: String

    @Option(name: .long, help: "Profile id (e.g. bass_lead_v1).")
    var profileId: String

    @Option(name: .long, help: "Macro to calibrate (e.g. Width).")
    var macro: String = "Width"

    @Option(name: .long, help: "Macro positions for sweep (e.g. 0,0.25,0.5,0.75,1).")
    var positions: String = "0,0.25,0.5,0.75,1"

    @Option(name: .long, help: "Export dir used by sweep-compile.")
    var exportDir: String

    @Option(name: .long, help: "MIDI dest contains (IAC recommended).")
    var midiDest: String = "IAC"

    @Option(name: .long, help: "CC mapped to macro in Ableton.")
    var cc: Int

    @Option(name: .long, help: "MIDI channel (1-16).")
    var channel: Int = 1

    @Option(name: .long, help: "Baseline mode: use|set-if-missing|update")
    var baselineMode: String = "set-if-missing"

    @Option(name: .long, help: "Baseline path (canonical). If omitted, uses profiles/<active_profile>/specs/sonic/baselines/<rack>/<macro>.baseline.v1.json")
    var baseline: String?

    @Option(name: .long, help: "Release output path override (optional).")
    var releaseOut: String?

    @Option(name: .long, help: "Thresholds JSON for sweep (optional).")
    var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/bass_music_sweep_defaults.v1.json")

    func run() async throws {
      let receipt = try await PipelineService.cutProfile(config: .init(profileDev: profileDev,
                                                                        rackId: rackId,
                                                                        profileId: profileId,
                                                                        macro: macro,
                                                                        positions: positions,
                                                                        exportDir: exportDir,
                                                                        midiDest: midiDest,
                                                                        cc: cc,
                                                                        channel: channel,
                                                                        baselineMode: baselineMode,
                                                                        baseline: baseline,
                                                                        releaseOut: releaseOut,
                                                                        thresholds: thresholds,
                                                                        runsDir: "runs"))
      print("receipt: runs/\(receipt.runId)/release_cut_receipt.v1.json")
      if receipt.status != "pass" { throw ExitCode(1) }
    }
  }
}
