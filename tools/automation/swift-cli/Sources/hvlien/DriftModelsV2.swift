import Foundation

struct DriftReportV2: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let status: String
  let summary: String
  let findings: [Finding]
  let reasons: [String]
  let recommendedFixes: [Fix]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case status
    case summary
    case findings
    case reasons
    case recommendedFixes = "recommended_fixes"
  }

  struct Finding: Codable {
    let id: String
    let severity: String
    let kind: String
    let artifactPath: String
    let title: String
    let why: String
    let fix: String
    let details: [String: String]?

    enum CodingKeys: String, CodingKey {
      case id, severity, kind
      case artifactPath = "artifact_path"
      case title, why, fix, details
    }
  }

  struct Fix: Codable {
    let id: String
    let command: String
    let covers: [String]     // artifact paths covered
    let notes: String
  }
}
