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
    let receipt = try await SonicCertifyService.run(config: .init(baseline: baseline,
                                                                  sweep: sweep,
                                                                  rackId: rackId,
                                                                  profileId: profileId,
                                                                  macro: macro,
                                                                  runsDir: RepoPaths.defaultRunsDir()))
    print("cert_receipt: \(RepoPaths.defaultRunsDir())/\(receipt.runId)/sonic_cert_receipt.v1.json")
    if receipt.status != "pass" { throw ExitCode(1) }
  }
}
