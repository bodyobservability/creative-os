import Foundation

struct VoiceCompliance: Codable {
  let structural: String
  let macroNames: String
  let ranges: String

  enum CodingKeys: String, CodingKey {
    case structural
    case macroNames = "macro_names"
    case ranges
  }
}

struct VoiceArtifacts: Codable {
  let promptCard: String
  let verifyPlan: String
  let doctorReport: String?
  let applyReceipt: String?
  let applyTrace: String?

  enum CodingKeys: String, CodingKey {
    case promptCard = "prompt_card"
    case verifyPlan = "verify_plan"
    case doctorReport = "doctor_report"
    case applyReceipt = "apply_receipt"
    case applyTrace = "apply_trace"
  }
}

struct VoiceReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let script: String
  let abi: String
  let status: String
  let compliance: VoiceCompliance
  let artifacts: VoiceArtifacts
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp, script, abi, status, compliance, artifacts, reasons
  }

  static func failed(runId: String, script: String, abi: String, card: String, verifyPlan: String,
                     doctorReport: String?, applyReceipt: String?, applyTrace: String?, reasons: [String]) -> VoiceReceiptV1 {
    VoiceReceiptV1(schemaVersion: 1,
                   runId: runId,
                   timestamp: ISO8601DateFormatter().string(from: Date()),
                   script: script,
                   abi: abi,
                   status: "fail",
                   compliance: VoiceCompliance(structural: "skip", macroNames: "skip", ranges: "skip"),
                   artifacts: VoiceArtifacts(promptCard: card, verifyPlan: verifyPlan, doctorReport: doctorReport, applyReceipt: applyReceipt, applyTrace: applyTrace),
                   reasons: reasons)
  }
}
