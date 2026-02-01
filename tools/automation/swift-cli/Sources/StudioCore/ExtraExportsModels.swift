import Foundation

struct ExtraExportItemV1: Codable {
  let id: String
  let outputPath: String
  let bytes: Int?
  let result: String
  let notes: String?

  enum CodingKeys: String, CodingKey {
    case id
    case outputPath = "output_path"
    case bytes
    case result
    case notes
  }
}

struct ExtraExportsReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let timestamp: String
  let job: String
  let status: String
  let items: [ExtraExportItemV1]
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
