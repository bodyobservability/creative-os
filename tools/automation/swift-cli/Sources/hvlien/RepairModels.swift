import Foundation

struct RepairReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let status: String
  let steps: [RepairStepV1]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case status
    case steps
    case reasons
  }
}

struct RepairStepV1: Codable {
  let id: String
  let command: String
  let exitCode: Int

  enum CodingKeys: String, CodingKey {
    case id
    case command
    case exitCode = "exit_code"
  }
}
