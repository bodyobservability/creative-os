import Foundation

struct FixCatalog {
  let anchorsPackHint: String?

  func suggestFix(for a: ArtifactIndexV1.Artifact) -> String {
    // Prefer a single actionable command.
    // If it's in known export paths, suggest targeted export; otherwise suggest export-all.
    let p = a.path
    let ap = anchorsPackHint ?? "specs/automation/anchors/<pack_id>"

    if p.contains("/ableton/racks/") {
      return "wub assets export-racks --anchors-pack \(ap) --overwrite"
    }
    if p.contains("/ableton/performance-sets/") {
      return "wub assets export-performance-set --anchors-pack \(ap) --overwrite"
    }
    if p.contains("/ableton/finishing-bays/") {
      return "wub assets export-finishing-bays --anchors-pack \(ap) --overwrite"
    }
    if p.contains("library/serum/") {
      return "wub assets export-serum-base --anchors-pack \(ap) --overwrite"
    }
    return "wub assets export-all --anchors-pack \(ap) --overwrite"
  }
}
