import Foundation
import ArgumentParser

/// v8.1: certify rack/profile against a stored sonic baseline
struct SonicCertifyCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "certify",
    abstract: "Certify a rack/profile against a stored sonic baseline."
  )

  @Option(name: .long) var baseline: String
  @Option(name: .long) var sweep: String
  @Option(name: .long) var rackId: String
  @Option(name: .long) var profileId: String
  @Option(name: .long) var macro: String

  struct SonicCertReceiptV1: Codable {
    let schemaVersion: Int
    let runId: String
    let timestamp: String
    let rackId: String
    let profileId: String
    let macro: String
    let status: String
    let artifacts: [String: String]
    let reasons: [String]

    enum CodingKeys: String, CodingKey {
      case schemaVersion = "schema_version"
      case runId = "run_id"
      case timestamp
      case rackId = "rack_id"
      case profileId = "profile_id"
      case macro
      case status
      case artifacts
      case reasons
    }
  }

  func run() async throws {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let exe = CommandLine.arguments.first ?? "hvlien"
    let diffOut = runDir.appendingPathComponent("sonic_diff_receipt.v1.json").path

    let code = try await runProcess(exe: exe, args: [
      "sonic","diff-sweep",
      "--baseline", baseline,
      "--current", sweep,
      "--out", diffOut
    ])

    let status = (code == 0) ? "pass" : "fail"
    let receipt = SonicCertReceiptV1(schemaVersion: 1,
                                     runId: runId,
                                     timestamp: ISO8601DateFormatter().string(from: Date()),
                                     rackId: rackId,
                                     profileId: profileId,
                                     macro: macro,
                                     status: status,
                                     artifacts: ["baseline": baseline, "current_sweep": sweep, "diff": diffOut],
                                     reasons: (code == 0) ? [] : ["diff_failed"])

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("sonic_cert_receipt.v1.json"))
    print("cert_receipt: runs/\(runId)/sonic_cert_receipt.v1.json")
    if status != "pass" { throw ExitCode(1) }
  }

  private func runProcess(exe: String, args: [String]) async throws -> Int32 {
    return try await withCheckedThrowingContinuation { cont in
      let p = Process()
      p.executableURL = URL(fileURLWithPath: exe)
      p.arguments = args
      p.standardOutput = FileHandle.standardOutput
      p.standardError = FileHandle.standardError
      p.terminationHandler = { proc in cont.resume(returning: proc.terminationStatus) }
      do { try p.run() } catch { cont.resume(throwing: error) }
    }
  }
}
