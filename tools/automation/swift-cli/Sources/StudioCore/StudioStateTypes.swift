import Foundation

enum GateStatus {
  case pass
  case fail
  case warn
  case pending
}

struct ReadinessGate {
  let key: String
  let label: String
  let status: GateStatus
  let detail: String?
  let nextAction: String?
}

struct RecommendedNext {
  let summary: String
  let command: [String]?
  let danger: Bool
}

struct StudioStateSnapshot {
  let gates: [ReadinessGate]
  let blockers: [String]
  let warnings: [String]
  let recommended: RecommendedNext
  let anchorsPack: String?
  let lastRunDir: String?
  let lastFailuresDir: String?
  let lastReadyReport: String?
  let pendingArtifacts: Int
  let placeholderArtifacts: Int
}
