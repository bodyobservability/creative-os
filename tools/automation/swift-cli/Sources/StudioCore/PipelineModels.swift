import Foundation

struct PipelineStepV1: Codable {
  let id: String
  let command: String
  let exitCode: Int
  enum CodingKeys: String, CodingKey { case id, command; case exitCode = "exit_code" }
}

struct ReleaseCutReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let status: String
  let inputs: [String: String]
  let steps: [PipelineStepV1]
  let artifacts: [String: String]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp, status, inputs, steps, artifacts, reasons
  }
}
