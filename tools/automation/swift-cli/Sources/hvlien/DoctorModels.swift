import Foundation
enum DoctorStatus: String, Codable { case pass, fail, skip }
struct DoctorReportV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  var status: DoctorStatus
  var checks: [DoctorCheckEntry]
  let artifactsDir: String
  enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case runId = "run_id"; case timestamp, status, checks; case artifactsDir = "artifacts_dir" }
}
struct DoctorCheckEntry: Codable {
  let id: String
  var status: DoctorStatus
  var details: [String: String]
  var artifacts: [String]
}
