import Foundation

struct PlanV1: Codable {
  let schemaVersion: Int
  let runId: String
  let mode: String
  let ops: [PlanOp]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case mode
    case ops
  }
}

struct PlanOp: Codable {
  let id: String
  let pre: [PlanAssert]?
  let action: PlanAction
  let post: [PlanAssert]?
  let recover: [PlanAction]?
  let retries: Int?
  let timeoutMs: Int?
  let notes: String?

  init(id: String,
       pre: [PlanAssert]? = nil,
       action: PlanAction,
       post: [PlanAssert]? = nil,
       recover: [PlanAction]? = nil,
       retries: Int? = nil,
       timeoutMs: Int? = nil,
       notes: String? = nil) {
    self.id = id
    self.pre = pre
    self.action = action
    self.post = post
    self.recover = recover
    self.retries = retries
    self.timeoutMs = timeoutMs
    self.notes = notes
  }

  enum CodingKeys: String, CodingKey {
    case id
    case pre
    case action = "do"
    case post
    case recover
    case retries
    case timeoutMs = "timeout_ms"
    case notes
  }
}

struct PlanAssert: Codable {
  let type: String
  let anchorId: String?
  let minScore: Double?
  let region: String?
  let text: String?
  let tokens: [String]?
  let minConf: Double?
  let pluginName: String?

  init(type: String,
       anchorId: String? = nil,
       minScore: Double? = nil,
       region: String? = nil,
       text: String? = nil,
       tokens: [String]? = nil,
       minConf: Double? = nil,
       pluginName: String? = nil) {
    self.type = type
    self.anchorId = anchorId
    self.minScore = minScore
    self.region = region
    self.text = text
    self.tokens = tokens
    self.minConf = minConf
    self.pluginName = pluginName
  }

  enum CodingKeys: String, CodingKey {
    case type
    case anchorId = "anchor_id"
    case minScore = "min_score"
    case region
    case text
    case tokens
    case minConf = "min_conf"
    case pluginName = "plugin_name"
  }
}

struct OCRMatchSpec: Codable {
  let text: String
  let mode: String
  let minConf: Double?

  enum CodingKeys: String, CodingKey {
    case text, mode
    case minConf = "min_conf"
  }
}

struct PlanAction: Codable {
  let type: String
  let keys: [String]?
  let text: String?
  let ms: Int?
  let anchorId: String?
  let fallbackRegion: String?
  let region: String?
  let match: OCRMatchSpec?
  let query: String?
  let pluginName: String?
  let deviceChainText: String?
  let openMethod: String?
  let midiDest: String?
  let channel: Int?
  let cc: Int?
  let value: Int?
  let note: Int?
  let velocity: Int?

  init(type: String,
       keys: [String]? = nil,
       text: String? = nil,
       ms: Int? = nil,
       anchorId: String? = nil,
       fallbackRegion: String? = nil,
       region: String? = nil,
       match: OCRMatchSpec? = nil,
       query: String? = nil,
       pluginName: String? = nil,
       deviceChainText: String? = nil,
       openMethod: String? = nil,
       midiDest: String? = nil,
       channel: Int? = nil,
       cc: Int? = nil,
       value: Int? = nil,
       note: Int? = nil,
       velocity: Int? = nil) {
    self.type = type
    self.keys = keys
    self.text = text
    self.ms = ms
    self.anchorId = anchorId
    self.fallbackRegion = fallbackRegion
    self.region = region
    self.match = match
    self.query = query
    self.pluginName = pluginName
    self.deviceChainText = deviceChainText
    self.openMethod = openMethod
    self.midiDest = midiDest
    self.channel = channel
    self.cc = cc
    self.value = value
    self.note = note
    self.velocity = velocity
  }

  enum CodingKeys: String, CodingKey {
    case type
    case keys
    case text
    case ms
    case anchorId = "anchor_id"
    case fallbackRegion = "fallback_region"
    case region
    case match
    case query
    case pluginName = "plugin_name"
    case deviceChainText = "device_chain_text"
    case openMethod = "open_method"
    case midiDest = "midi_dest"
    case channel
    case cc
    case value
    case note
    case velocity
  }
}
