import Foundation

struct SonicMetricsV1: Codable {
  let sampleRateHz: Double
  let channels: Int
  let durationS: Double
  let truePeakDbfs: Double
  let peakDbfs: Double
  let rmsDbfs: Double
  let dcOffset: Double
  let crestFactorDb: Double
  let stereoCorrelation: Double?

  enum CodingKeys: String, CodingKey {
    case sampleRateHz = "sample_rate_hz"
    case channels
    case durationS = "duration_s"
    case truePeakDbfs = "true_peak_dbfs"
    case peakDbfs = "peak_dbfs"
    case rmsDbfs = "rms_dbfs"
    case dcOffset = "dc_offset"
    case crestFactorDb = "crest_factor_db"
    case stereoCorrelation = "stereo_correlation"
  }
}

struct SonicReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let inputAudio: String
  let status: String
  let profileId: String?
  let rackId: String?
  let metrics: SonicMetricsV1
  let thresholds: [String: Double]?
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case inputAudio = "input_audio"
    case status
    case profileId = "profile_id"
    case rackId = "rack_id"
    case metrics
    case thresholds
    case reasons
  }
}
