import Foundation

struct SonicSweepSampleV1: Codable {
  let position: Double
  let inputAudio: String
  let metrics: SonicMetricsV1
  let status: String
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case position
    case inputAudio = "input_audio"
    case metrics
    case status
    case reasons
  }
}

struct SonicSweepSummaryV1: Codable {
  let worstTruePeakDbfs: Double
  let worstRmsDbfs: Double
  let worstDcOffsetAbs: Double
  let minStereoCorrelation: Double?
  let suggestedSafeMaxPosition: Double

  enum CodingKeys: String, CodingKey {
    case worstTruePeakDbfs = "worst_true_peak_dbfs"
    case worstRmsDbfs = "worst_rms_dbfs"
    case worstDcOffsetAbs = "worst_dc_offset_abs"
    case minStereoCorrelation = "min_stereo_correlation"
    case suggestedSafeMaxPosition = "suggested_safe_max_position"
  }
}

struct SonicSweepReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let macro: String
  let profileId: String?
  let rackId: String?
  let positions: [Double]
  let status: String
  let thresholds: [String: Double]?
  let summary: SonicSweepSummaryV1
  let samples: [SonicSweepSampleV1]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case macro
    case profileId = "profile_id"
    case rackId = "rack_id"
    case positions
    case status
    case thresholds
    case summary
    case samples
  }
}
