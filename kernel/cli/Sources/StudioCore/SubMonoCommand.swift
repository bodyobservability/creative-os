import Foundation
import ArgumentParser

struct SubMonoCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sub-mono",
    abstract: "Analyze sub-band mono safety (20-120 Hz) and emit a sub-mono safety receipt."
  )

  @Option(name: .long, help: "Input audio file path (wav/aiff).")
  var input: String

  @Option(name: .long, help: "Thresholds JSON path (optional).")
  var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/sub_mono_safety_defaults.v1.json")

  @Option(name: .long, help: "Output receipt path (default: runs/<run_id>/sub_mono_safety_receipt.v1.json).")
  var out: String?

  @Option(name: .long) var rackId: String?
  @Option(name: .long) var profileId: String?

  func run() throws {
    let result = try SubMonoService.run(config: .init(input: input,
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
