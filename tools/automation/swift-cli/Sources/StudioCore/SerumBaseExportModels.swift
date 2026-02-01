import Foundation

struct SerumBaseExportReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let job: String
  let status: String
  let targetPath: String
  let bytes: Int?
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case job
    case status
    case targetPath = "target_path"
    case bytes
    case reasons
  }
}
