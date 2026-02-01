import Foundation

struct SonicDiffDeltasV1: Codable {
  let worstTruePeakDb: Double
  let worstRmsDb: Double
  let worstDcOffsetAbs: Double
  let minStereoCorr: Double?
  let safeMaxPositionDelta: Double

  enum CodingKeys: String, CodingKey {
    case worstTruePeakDb = "worst_true_peak_db"
    case worstRmsDb = "worst_rms_db"
    case worstDcOffsetAbs = "worst_dc_offset_abs"
    case minStereoCorr = "min_stereo_corr"
    case safeMaxPositionDelta = "safe_max_position_delta"
  }
}

struct SonicDiffReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let baseline: String
  let current: String
  let status: String
  let deltas: SonicDiffDeltasV1
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case baseline
    case current
    case status
    case deltas
    case reasons
  }
}

struct ProfilePatchChangeV1: Codable {
  let path: String
  let before: [Double]
  let after: [Double]
}

struct ProfilePatchReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let profileIn: String
  let tunedIn: String
  let status: String
  let patchPath: String
  let changes: [ProfilePatchChangeV1]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case profileIn = "profile_in"
    case tunedIn = "tuned_in"
    case status
    case patchPath = "patch_path"
    case changes
    case reasons
  }
}
