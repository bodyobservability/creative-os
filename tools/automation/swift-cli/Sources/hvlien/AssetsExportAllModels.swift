import Foundation

struct AssetsExportStepV1: Codable {
  let id: String
  let command: String
  let exitCode: Int
  enum CodingKeys: String, CodingKey { case id, command; case exitCode = "exit_code" }
}

struct AssetsExportAllReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let job: String
  let status: String
  let steps: [AssetsExportStepV1]
  let artifacts: [String: String]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case job
    case status
    case steps
    case artifacts
    case reasons
  }
}
