import Foundation

struct SessionReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let profileId: String
  let status: String
  let artifacts: Artifacts
  let steps: [Step]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case profileId = "profile_id"
    case status, artifacts, steps, reasons
  }

  struct Artifacts: Codable {
    let sessionDir: String
    let voiceReceipt: String?
    let rackInstallReceipt: String?
    let rackVerifyReceipt: String?
    let doctorReport: String?
    let applyReceipt: String?
    let applyTrace: String?

    enum CodingKeys: String, CodingKey {
      case sessionDir = "session_dir"
      case voiceReceipt = "voice_receipt"
      case rackInstallReceipt = "rack_install_receipt"
      case rackVerifyReceipt = "rack_verify_receipt"
      case doctorReport = "doctor_report"
      case applyReceipt = "apply_receipt"
      case applyTrace = "apply_trace"
    }
  }

  struct Step: Codable {
    let id: String
    let command: String
    let exitCode: Int
    let notes: String?
    enum CodingKeys: String, CodingKey { case id, command; case exitCode = "exit_code"; case notes }
  }
}
