import Foundation

struct TraceV1: Codable {
  let schemaVersion: Int
  let runId: String
  let startedAt: String
  var ops: [TraceOp]
  enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case runId = "run_id"; case startedAt = "started_at"; case ops }
}

struct TraceOp: Codable {
  let opId: String
  var attempts: [TraceAttempt]
  enum CodingKeys: String, CodingKey { case opId = "op_id"; case attempts }
}

struct TraceAttempt: Codable {
  let attemptIndex: Int
  let startedAt: String
  var events: [TraceEvent]
  var result: String
  enum CodingKeys: String, CodingKey { case attemptIndex = "attempt_index"; case startedAt = "started_at"; case events; case result }
}

struct TraceEvent: Codable {
  let tMs: Int
  let kind: String
  let name: String
  let details: [String: String]
  enum CodingKeys: String, CodingKey { case tMs = "t_ms"; case kind, name, details }
}
