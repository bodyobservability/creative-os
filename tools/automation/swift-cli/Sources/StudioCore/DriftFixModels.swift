import Foundation

struct DriftFixStepV1: Codable {
  let id: String
  let command: String
  let exitCode: Int
  let notes: String?

  enum CodingKeys: String, CodingKey { case id, command; case exitCode = "exit_code"; case notes }
}

struct DriftFixReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let status: String
  let plan: [String]
  let steps: [DriftFixStepV1]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case status
    case plan
    case steps
    case reasons
  }
}
