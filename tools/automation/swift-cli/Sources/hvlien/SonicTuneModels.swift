import Foundation

struct SonicTuneChangeV1: Codable {
  let macro: String
  let path: String
  let before: [Double]
  let after: [Double]
}

struct SonicTuneReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let inputSweepReceipt: String
  let profileIn: String
  let profileOut: String
  let status: String
  let macro: String
  let suggestedSafeMaxPosition: Double
  let changes: [SonicTuneChangeV1]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case inputSweepReceipt = "input_sweep_receipt"
    case profileIn = "profile_in"
    case profileOut = "profile_out"
    case status
    case macro
    case suggestedSafeMaxPosition = "suggested_safe_max_position"
    case changes
    case reasons
  }
}
