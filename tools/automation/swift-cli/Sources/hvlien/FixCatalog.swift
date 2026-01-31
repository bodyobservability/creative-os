import Foundation

struct FixCatalog {
  let anchorsPackHint: String?

  func suggestFix(for a: ArtifactIndexV1.Artifact) -> String {
    // Prefer a single actionable command.
    // If it's in known export paths, suggest targeted export; otherwise suggest export-all.
    let p = a.path
    let ap = anchorsPackHint ?? "specs/automation/anchors/<pack_id>"

    if p.contains("ableton/racks/") {
      return "hvlien assets export-racks --anchors-pack \(ap) --overwrite"
    }
    if p.contains("ableton/performance-sets/") {
      return "hvlien assets export-performance-set --anchors-pack \(ap) --overwrite"
    }
    if p.contains("ableton/finishing-bays/") {
      return "hvlien assets export-finishing-bays --anchors-pack \(ap) --overwrite"
    }
    if p.contains("library/serum/") {
      return "hvlien assets export-serum-base --anchors-pack \(ap) --overwrite"
    }
    return "hvlien assets export-all --anchors-pack \(ap) --overwrite"
  }
}
