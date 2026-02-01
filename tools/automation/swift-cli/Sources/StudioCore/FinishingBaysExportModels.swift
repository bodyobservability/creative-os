import Foundation

struct FinishingBayExportItemV1: Codable {
  let bayId: String
  let name: String
  let targetPath: String
  let bytes: Int?
  let result: String   // exported|skipped|failed
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case bayId = "bay_id"
    case name
    case targetPath = "target_path"
    case bytes
    case result
    case notes
  }
}

struct FinishingBaysExportReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let job: String
  let status: String
  let items: [FinishingBayExportItemV1]
  let reasons: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case timestamp
    case job
    case status
    case items
    case reasons
  }
}
