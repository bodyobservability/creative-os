import Foundation
import ArgumentParser

/// v7.5: Apply sweep-derived safe max to a macro mapping profile.
struct SonicTuneCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "tune-profile",
    abstract: "Tune a profile YAML using a v7.2 sonic sweep receipt (clamps macro max range)."
  )

  @Option(name: .long, help: "Input sweep receipt JSON (v7.2).")
  var sweepReceipt: String

  @Option(name: .long, help: "Profile YAML to tune (v6.1 profile).")
  var profile: String

  @Option(name: .long, help: "Output tuned profile path (optional).")
  var out: String?

  @Option(name: .long, help: "Output receipt path (optional). Default \(RepoPaths.defaultRunsDir())/<run_id>/sonic_tune_receipt.v1.json")
  var receiptOut: String?

  func run() throws {
    let (outProfile, receipt) = try SonicTune.tuneProfile(profileYamlPath: profile, sweepReceiptPath: sweepReceipt, outPath: out)

    let runDir = URL(fileURLWithPath: RepoPaths.defaultRunsDir()).appendingPathComponent(receipt.runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let receiptPath = receiptOut ?? runDir.appendingPathComponent("sonic_tune_receipt.v1.json").path
    try JSONIO.save(receipt, to: URL(fileURLWithPath: receiptPath))

    print("tuned_profile: \(outProfile)")
    print("receipt: \(receiptPath)")
    if receipt.status == "fail" { throw ExitCode(1) }
  }
}
