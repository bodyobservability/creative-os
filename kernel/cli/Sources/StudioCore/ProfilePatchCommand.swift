import Foundation
import ArgumentParser

struct ProfilePatchCommand: ParsableCommand {
  static let configuration = CommandConfiguration(commandName: "patch-profile",
    abstract: "Emit a minimal profile patch JSON by diffing an original profile YAML vs tuned YAML.")

  @Option(name: .long) var profile: String
  @Option(name: .long) var tuned: String
  @Option(name: .long) var out: String?
  @Option(name: .long) var receiptOut: String?

  func run() throws {
    let (patchPath, receipt) = try ProfilePatch.emit(profileIn: profile, tunedIn: tuned, patchOut: out)

    let runDir = URL(fileURLWithPath: RepoPaths.defaultRunsDir()).appendingPathComponent(receipt.runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let receiptPath = receiptOut ?? runDir.appendingPathComponent("profile_patch_receipt.v1.json").path
    try JSONIO.save(receipt, to: URL(fileURLWithPath: receiptPath))

    print("patch: \(patchPath)")
    print("receipt: \(receiptPath)")
    if receipt.status == "fail" { throw ExitCode(1) }
  }
}
