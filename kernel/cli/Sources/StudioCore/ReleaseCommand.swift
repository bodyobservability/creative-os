import Foundation
import ArgumentParser

struct Release: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "release",
    abstract: "Release channel governance (v8.2).",
    subcommands: [PromoteProfile.self]
  )

  struct PromoteProfile: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "promote-profile",
      abstract: "Promote a tuned profile from dev->release after passing certification gates."
    )

    @Option(name: .long, help: "Tuned profile YAML path (candidate).")
    var profile: String

    @Option(name: .long, help: "Release output path (default: shared/specs/profiles/<active_profile>/library/profiles/release/<name>.yaml).")
    var out: String?

    @Option(name: .long, help: "Rack id used for baseline certification.")
    var rackId: String

    @Option(name: .long, help: "Macro used for baseline certification (e.g. Width).")
    var macro: String

    @Option(name: .long, help: "Baseline sweep receipt path.")
    var baseline: String

    @Option(name: .long, help: "Current sweep receipt path (from latest calibration).")
    var currentSweep: String

    @Option(name: .long, help: "Rack manifest path (optional).")
    var rackManifest: String = WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json")

    func run() async throws {
      let receipt = try await ReleaseService.promoteProfile(config: .init(profile: profile,
                                                                           out: out,
                                                                           rackId: rackId,
                                                                           macro: macro,
                                                                           baseline: baseline,
                                                                           currentSweep: currentSweep,
                                                                           rackManifest: rackManifest,
                                                                           runsDir: RepoPaths.defaultRunsDir()))
      print("receipt: \(RepoPaths.defaultRunsDir())/\(receipt.runId)/profile_promotion_receipt.v1.json")
      if receipt.status != "pass" { throw ExitCode(1) }
    }
  }
}
