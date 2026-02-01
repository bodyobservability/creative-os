import Foundation

struct ReadyCheckV1: Codable {
  let id: String
  let status: String
  let details: [String: String]
}

struct ReadyReportV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let status: String
  let checks: [ReadyCheckV1]
  let recommendedCommands: [String]
  let notes: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case status
    case checks
    case recommendedCommands = "recommended_commands"
    case notes
  }
}
