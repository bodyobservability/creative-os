import Foundation

struct SubMonoMetricsV1: Codable {
  let sampleRateHz: Double
  let durationS: Double
  let subMidRms: Double
  let subSideRms: Double
  let subSideRatio: Double
  let subCorr: Double
  let subDcOffset: Double
  let subTruePeakDbfs: Double

  enum CodingKeys: String, CodingKey {
    case sampleRateHz = "sample_rate_hz"
    case durationS = "duration_s"
    case subMidRms = "sub_mid_rms"
    case subSideRms = "sub_side_rms"
    case subSideRatio = "sub_side_ratio"
    case subCorr = "sub_corr"
    case subDcOffset = "sub_dc_offset"
    case subTruePeakDbfs = "sub_true_peak_dbfs"
  }
}

struct SubMonoSafetyReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let inputAudio: String
  let rackId: String?
  let profileId: String?
  let status: String
  let bandsHz: [String: [Double]]
  let metrics: SubMonoMetricsV1
  let thresholds: [String: Double]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case inputAudio = "input_audio"
    case rackId = "rack_id"
    case profileId = "profile_id"
    case status
    case bandsHz = "bands_hz"
    case metrics
    case thresholds
    case reasons
  }
}
