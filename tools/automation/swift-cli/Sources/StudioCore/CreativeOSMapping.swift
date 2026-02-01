import Foundation

struct CreativeOSMapping {
  struct Entry: Codable, Equatable {
    let legacyArtifact: String
    let newHome: String
  }

  static let entries: [Entry] = [
    .init(legacyArtifact: "specs", newHome: "agent checks"),
    .init(legacyArtifact: "receipts", newHome: "observed state snapshots"),
    .init(legacyArtifact: "checksums", newHome: "plan validation inputs"),
    .init(legacyArtifact: "anchor packs", newHome: "profile packs"),
    .init(legacyArtifact: "automation plans", newHome: "agent PlanSteps")
  ]

  static func validate() -> [String] {
    var issues: [String] = []
    if entries.isEmpty { issues.append("mapping_table_empty") }
    var seen = Set<String>()
    for entry in entries {
      if entry.legacyArtifact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("legacy_artifact_empty")
      }
      if entry.newHome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        issues.append("new_home_empty")
      }
      if seen.contains(entry.legacyArtifact) {
        issues.append("duplicate_legacy_artifact:\(entry.legacyArtifact)")
      }
      seen.insert(entry.legacyArtifact)
    }
    return issues
  }
}
