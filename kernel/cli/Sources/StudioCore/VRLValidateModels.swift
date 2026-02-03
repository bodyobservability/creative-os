import Foundation

struct VRLCheckEntry: Codable {
  let id: String
  let status: String
  let details: [String: String]
}

struct VRLValidateReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let mappingSpec: String
  let status: String
  let checks: [VRLCheckEntry]
  let artifacts: [String: String]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case mappingSpec = "mapping_spec"
    case status
    case checks
    case artifacts
    case reasons
  }
}
