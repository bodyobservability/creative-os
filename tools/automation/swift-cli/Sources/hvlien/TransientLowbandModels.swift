import Foundation

struct TransientLowbandMetricsV1: Codable {
  let sampleRateHz: Double
  let durationS: Double
  let lowRmsDbfs: Double
  let lowTruePeakDbfs: Double
  let lowCrestDb: Double
  let subTruePeakDbfs: Double

  enum CodingKeys: String, CodingKey {
    case sampleRateHz = "sample_rate_hz"
    case durationS = "duration_s"
    case lowRmsDbfs = "low_rms_dbfs"
    case lowTruePeakDbfs = "low_true_peak_dbfs"
    case lowCrestDb = "low_crest_db"
    case subTruePeakDbfs = "sub_true_peak_dbfs"
  }
}

struct TransientLowbandReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let inputAudio: String
  let rackId: String?
  let profileId: String?
  let status: String
  let bandsHz: [String: [Double]]
  let metrics: TransientLowbandMetricsV1
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
