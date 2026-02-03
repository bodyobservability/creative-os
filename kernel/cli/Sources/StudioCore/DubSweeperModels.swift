import Foundation
enum DubSweeperStatus: String, Codable { case pass, fail, skip }

struct DubSweeperStep: Codable {
  let id: String
  let description: String
}

struct DubSweeperReportV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  var status: DubSweeperStatus
  var checks: [DubSweeperCheckEntry]
  var safeSteps: [DubSweeperStep]
  var manualSteps: [DubSweeperStep]
  let artifactsDir: String

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp, status, checks
    case safeSteps = "safe_steps"
    case manualSteps = "manual_steps"
    case artifactsDir = "artifacts_dir"
  }
}

struct DubSweeperCheckEntry: Codable {
  let id: String
  var status: DubSweeperStatus
  var details: [String: String]
  var artifacts: [String]
}
