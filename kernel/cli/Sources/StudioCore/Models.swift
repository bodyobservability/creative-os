import Foundation

struct Prompt: Codable {
  let type: String
  let title: String
  let message: String
  let relatedRequestId: String?
  enum CodingKeys: String, CodingKey { case type, title, message; case relatedRequestId = "related_request_id" }
}

struct ResolveResult: Codable {
  let requestId: String
  let decision: String
  enum CodingKeys: String, CodingKey { case requestId = "request_id"; case decision }
}

struct ResolveReport: Codable {
  let schemaVersion: Int
  let generatedAt: String
  let environment: [String: String]
  let results: [ResolveResult]
  let prompts: [Prompt]
  let meta: [String: String]?
  enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case generatedAt = "generated_at"; case environment, results, prompts, meta }
}

// Inventory
struct EvidenceSample: Codable {
  let runId: String
  let frameTsMs: Int
  let regionId: String
  let ocrText: String
  let confidence: Double
  let screenshotRelpath: String?
  enum CodingKeys: String, CodingKey { case runId = "run_id"; case frameTsMs = "frame_ts_ms"; case regionId = "region_id"; case ocrText = "ocr_text"; case confidence; case screenshotRelpath = "screenshot_relpath" }
}
struct Evidence: Codable { var seenCount: Int?; var bestConfidence: Double?; var samples: [EvidenceSample]
  enum CodingKeys: String, CodingKey { case seenCount = "seen_count"; case bestConfidence = "best_confidence"; case samples }
}
struct InventoryItem: Codable {
  var id: String
  var stableKey: String?
  var displayName: String
  var normName: String
  var kind: String
  var format: String?
  var vendor: String?
  var tags: [String]
  var browserPath: [String]
  var evidence: Evidence
  enum CodingKeys: String, CodingKey {
    case id; case stableKey = "stable_key"; case displayName = "display_name"; case normName = "norm_name"
    case kind, format, vendor, tags; case browserPath = "browser_path"; case evidence
  }
}
struct InventoryDoc: Codable {
  let schemaVersion: Int
  let generatedAt: String
  let environment: [String: String]
  let source: [String: String]
  let items: [InventoryItem]
  enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case generatedAt = "generated_at"; case environment, source, items }
}

// Controllers inventory
struct MidiEndpoint: Codable {
  let id: String
  let displayName: String
  let normName: String
  let direction: String
  let uniqueId: Int32?
  enum CodingKeys: String, CodingKey { case id; case displayName = "display_name"; case normName = "norm_name"; case direction; case uniqueId = "unique_id" }
}
struct ControllerDevice: Codable {
  let id: String
  let displayName: String
  let normName: String
  let manufacturer: String?
  let model: String?
  let endpointsIn: [MidiEndpoint]
  let endpointsOut: [MidiEndpoint]
}
struct ControllersInventoryDoc: Codable {
  let schemaVersion: Int
  let generatedAt: String
  let environment: [String: String]
  let devices: [ControllerDevice]
  enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case generatedAt = "generated_at"; case environment, devices }
}

// Substitutions / Recommendations / Packs (minimal decoders)
struct SubstitutionsDoc: Codable {
  struct Candidate: Codable { let name: String; let kind: String?; let format: String?; let vendor: String?; let weight: Double; let notes: String? }
  struct When: Codable { let tagsAny: [String]?; enum CodingKeys: String, CodingKey { case tagsAny = "tags_any" } }
  struct Then: Codable { let candidates: [Candidate] }
  struct Rule: Codable { let id: String; let when: When; let then: Then }
  let rules: [Rule]
}
struct RecommendationsDoc: Codable {
  struct Suggestion: Codable { let type: String; let name: String; let vendor: String?; let notes: String? }
  struct TagRec: Codable { let priority: Int; let why: String; let suggestions: [Suggestion] }
  let tags: [String: TagRec]
}
struct PackSignaturesDoc: Codable {
  struct Token: Codable { let expectContains: String; enum CodingKeys: String, CodingKey { case expectContains = "expect_contains" } }
  struct InstallPrompt: Codable { let title: String; let message: String }
  struct Pack: Codable {
    let packId: String
    let packName: String
    let impliedByTagsAny: [String]?
    let impliedByTagsAll: [String]?
    let signatureTokens: [Token]
    let minHits: Int
    let confidenceThreshold: Double
    let installPrompt: InstallPrompt
    enum CodingKeys: String, CodingKey {
      case packId = "pack_id"; case packName = "pack_name"
      case impliedByTagsAny = "implied_by_tags_any"; case impliedByTagsAll = "implied_by_tags_all"
      case signatureTokens = "signature_tokens"; case minHits = "min_hits"; case confidenceThreshold = "confidence_threshold"
      case installPrompt = "install_prompt"
    }
  }
  let packs: [Pack]
}

// Requests
enum MatchMode: String, Codable { case exact, contains, fuzzy }
struct DeviceRequest { let id: String; let primary: String; let candidates: [String]; let matchMode: MatchMode; let required: Bool; let tags: [String]; let kindPreference: [String]; let formatPreference: [String]; let vendorPreference: [String]; let trackType: String? }
struct ControllerRequest { let id: String; let required: Bool; let expectedNameContains: [String]; let preferredManufacturer: String?; let requireInputContains: [String]?; let requireOutputContains: [String]?; let expectedControlSurfaceName: String? }
struct PackCheckRequest { let id: String; let packId: String; let required: Bool; let becauseTags: [String] }
struct CompiledSpec { let deviceRequests: [DeviceRequest]; let controllerRequests: [ControllerRequest]; let packChecks: [PackCheckRequest] }
