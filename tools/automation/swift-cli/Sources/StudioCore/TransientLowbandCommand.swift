import Foundation
import ArgumentParser

struct TransientLowbandCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "transient-low",
    abstract: "Analyze low-band transient/headroom safety and emit a receipt."
  )

  @Option(name: .long) var input: String
  @Option(name: .long) var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/transient_lowband_defaults.v1.json")
  @Option(name: .long) var out: String?
  @Option(name: .long) var rackId: String?
  @Option(name: .long) var profileId: String?

  func run() throws {
    let result = try TransientLowbandService.run(config: .init(input: input,
                                                               thresholds: thresholds,
                                                               out: out,
                                                               rackId: rackId,
                                                               profileId: profileId,
                                                               runsDir: "runs"))
    print("status: \(result.receipt.status)")
    if !result.receipt.reasons.isEmpty { print("reasons:"); for r in result.receipt.reasons { print(" - \(r)") } }
    print("receipt: \(result.outPath)")
    if result.receipt.status == "fail" { throw ExitCode(1) }
  }
}
