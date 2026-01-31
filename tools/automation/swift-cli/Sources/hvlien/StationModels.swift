import Foundation

struct StationStepV1: Codable {
  let id: String
  let command: String
  let exitCode: Int
  enum CodingKeys: String, CodingKey { case id, command; case exitCode = "exit_code" }
}

struct StationReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let stationProfile: String
  let status: String
  let artifacts: [String: String]
  let steps: [StationStepV1]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case stationProfile = "station_profile"
    case status
    case artifacts
    case steps
    case reasons
  }
}
