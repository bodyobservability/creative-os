import Foundation

struct SonicCalibrateStepV1: Codable {
  let id: String
  let command: String
  let exitCode: Int
  enum CodingKeys: String, CodingKey { case id, command; case exitCode = "exit_code" }
}

struct SonicCalibrateArtifactsV1: Codable {
  let exportDir: String
  let sweepReceipt: String
  let tuneReceipt: String
  let runDir: String
  enum CodingKeys: String, CodingKey { case exportDir = "export_dir"; case sweepReceipt = "sweep_receipt"; case tuneReceipt = "tune_receipt"; case runDir = "run_dir" }
}

struct SonicCalibrateReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let macro: String
  let positions: [Double]
  let profileIn: String
  let profileOut: String
  let rackId: String?
  let profileId: String?
  let status: String
  let artifacts: SonicCalibrateArtifactsV1
  let steps: [SonicCalibrateStepV1]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp, macro, positions
    case profileIn = "profile_in"
    case profileOut = "profile_out"
    case rackId = "rack_id"
    case profileId = "profile_id"
    case status, artifacts, steps, reasons
  }
}
