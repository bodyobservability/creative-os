import Foundation

struct ExportPreflightReportV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let status: String
  let checks: [ExportPreflightCheckV1]
  let notes: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case status
    case checks
    case notes
  }
}

struct ExportPreflightCheckV1: Codable {
  let id: String
  let status: String
  let details: [String: String]
}
