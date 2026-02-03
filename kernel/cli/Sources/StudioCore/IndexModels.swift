import Foundation

struct ArtifactIndexV1: Codable {
  let schemaVersion: Int
  let generatedAt: String
  let repoVersion: String
  let artifacts: [Artifact]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case generatedAt = "generated_at"
    case repoVersion = "repo_version"
    case artifacts
  }

  struct Export: Codable {
    let job: String
    let runId: String
    let receiptPath: String
    let exportedAt: String

    enum CodingKeys: String, CodingKey {
      case job
      case runId = "run_id"
      case receiptPath = "receipt_path"
      case exportedAt = "exported_at"
    }
  }

  struct Dependencies: Codable {
    let racks: [String]?
    let profiles: [String]?
    let macros: [String]?
  }

  struct Status: Codable {
    let state: String
    let reason: String
  }

  struct Artifact: Codable {
    let artifactId: String
    let kind: String
    let path: String
    let exists: Bool
    let bytes: Int?
    let sha256: String?
    let mtime: String?
    let export: Export?
    let dependencies: Dependencies?
    let status: Status

    enum CodingKeys: String, CodingKey {
      case artifactId = "artifact_id"
      case kind
      case path
      case exists
      case bytes
      case sha256
      case mtime
      case export
      case dependencies
      case status
    }
  }
}

struct ReceiptIndexV1: Codable {
  let schemaVersion: Int
  let generatedAt: String
  let receipts: [Receipt]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case generatedAt = "generated_at"
    case receipts
  }

  struct Receipt: Codable {
    let receiptId: String
    let kind: String
    let path: String
    let runId: String
    let timestamp: String
    let status: String?

    enum CodingKeys: String, CodingKey {
      case receiptId = "receipt_id"
      case kind
      case path
      case runId = "run_id"
      case timestamp
      case status
    }
  }
}

struct ExpectedArtifactV1 {
  let kind: String
  let path: String
  let minBytes: Int?
  let warnBytes: Int?
  let job: String?
}
