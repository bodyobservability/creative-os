import Foundation

struct PromotionGateResult: Codable {
  let id: String
  let command: String
  let exitCode: Int
  enum CodingKeys: String, CodingKey { case id, command; case exitCode = "exit_code" }
}

struct ProfilePromotionReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let profileIn: String
  let profileOut: String
  let status: String
  let gates: [PromotionGateResult]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case profileIn = "profile_in"
    case profileOut = "profile_out"
    case status
    case gates
    case reasons
  }
}
