import Foundation

struct RacksExportItemV1: Codable {
  let rackId: String
  let displayName: String
  let targetTrack: String?
  let targetPath: String
  let bytes: Int?
  let result: String     // exported|skipped|failed
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case rackId = "rack_id"
    case displayName = "display_name"
    case targetTrack = "target_track"
    case targetPath = "target_path"
    case bytes
    case result
    case notes
  }
}

struct RacksExportReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let job: String
  let status: String     // pass|warn|fail
  let outputDir: String
  let items: [RacksExportItemV1]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case job
    case status
    case outputDir = "output_dir"
    case items
    case reasons
  }
}
