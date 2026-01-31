import Foundation

struct RackPackManifestV1: Codable {
  struct AppliesTo: Codable { let os: String; let ableton: String }
  struct Req: Codable {
    let kind: String
    let name: String
    let format: String?
    let vendor: String?
    let optional: Bool
  }
  struct Check: Codable {
    let type: String
    let region: String
    let tokens: [String]
    let minConf: Double
    enum CodingKeys: String, CodingKey { case type, region, tokens; case minConf = "min_conf" }
  }
  struct Verification: Codable {
    let regions: [String]
    let checks: [Check]
  }
  struct Rack: Codable {
    let rackId: String
    let displayName: String
    let type: String
    let profileBinding: String
    let targetTrack: String?
    let expectedTokens: [String]?
    let macroAbi: String
    let macroNames: [String]
    let requires: [Req]
    let verification: Verification
    let notes: String?
    enum CodingKeys: String, CodingKey {
      case rackId = "rack_id"
      case displayName = "display_name"
      case type
      case profileBinding = "profile_binding"
      case targetTrack = "target_track"
      case expectedTokens = "expected_tokens"
      case macroAbi = "macro_abi"
      case macroNames = "macro_names"
      case requires, verification, notes
    }
  }

  let schemaVersion: Int
  let name: String
  let appliesTo: AppliesTo
  let racks: [Rack]
  let notes: String?
  enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case name; case appliesTo = "applies_to"; case racks; case notes }
}

struct RackComplianceReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let manifestPath: String
  let status: String
  let planPath: String
  let applyReceiptPath: String?
  let applyTracePath: String?
  let results: [RackResult]
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
    case results
    case reasons
  }

  struct RackResult: Codable {
    let rackId: String
    let trackHint: String?
    let status: String
    let notes: String?
    enum CodingKeys: String, CodingKey { case rackId = "rack_id"; case trackHint = "track_hint"; case status; case notes }
  }
}
