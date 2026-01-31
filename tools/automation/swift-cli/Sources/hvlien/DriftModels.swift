import Foundation

struct DriftReportV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let status: String
  let summary: String
  let findings: [Finding]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case status
    case summary
    case findings
    case reasons
  }

  struct Finding: Codable {
    let id: String
    let severity: String      // info|warn|fail
    let kind: String          // missing|placeholder|stale|unknown
    let artifactPath: String
    let title: String
    let why: String
    let fix: String
    let details: [String: String]?

    enum CodingKeys: String, CodingKey {
      case id
      case severity
      case kind
      case artifactPath = "artifact_path"
      case title
      case why
      case fix
      case details
    }
  }
}
