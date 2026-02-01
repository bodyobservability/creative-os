import Foundation

struct RackInstallReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let manifestPath: String
  let status: String
  let planPath: String
  let applyReceiptPath: String?
  let applyTracePath: String?
  let installed: [InstalledRack]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case manifestPath = "manifest_path"
    case status
    case planPath = "plan_path"
    case applyReceiptPath = "apply_receipt_path"
    case applyTracePath = "apply_trace_path"
    case installed
    case reasons
  }

  struct InstalledRack: Codable {
    let rackId: String
    let targetTrack: String
    let decision: String
    let notes: String?
    enum CodingKeys: String, CodingKey { case rackId = "rack_id"; case targetTrack = "target_track"; case decision; case notes }
  }
}
