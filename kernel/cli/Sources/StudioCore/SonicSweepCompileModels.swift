import Foundation

struct SonicSweepCompileStep: Codable {
  let id: String
  let detail: String
  let exitCode: Int
  enum CodingKeys: String, CodingKey { case id, detail; case exitCode = "exit_code" }
}

struct SonicSweepCompileArtifacts: Codable {
  let exportDir: String
  let sweepReceipt: String
  let runDir: String
  enum CodingKeys: String, CodingKey { case exportDir = "export_dir"; case sweepReceipt = "sweep_receipt"; case runDir = "run_dir" }
}

struct SonicSweepCompileMidi: Codable {
  let cc: Int
  let channel: Int
  let portNameContains: String
  enum CodingKeys: String, CodingKey { case cc, channel; case portNameContains = "port_name_contains" }
}

struct SonicSweepCompileReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let macro: String
  let positions: [Double]
  let rackId: String?
  let profileId: String?
  let midi: SonicSweepCompileMidi
  let status: String
  let artifacts: SonicSweepCompileArtifacts
  let steps: [SonicSweepCompileStep]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp, macro, positions
    case rackId = "rack_id"
    case profileId = "profile_id"
    case midi, status, artifacts, steps, reasons
  }
}
