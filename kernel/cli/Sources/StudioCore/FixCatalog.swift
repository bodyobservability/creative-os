import Foundation

struct FixCatalog {
  let anchorsPackHint: String?

  func suggestFix(for a: ArtifactIndexV1.Artifact) -> String {
    // Prefer a single actionable command.
    // If it's in known export paths, suggest targeted export; otherwise suggest export-all.
    let p = a.path
    let ap = anchorsPackHint ?? "shared/specs/automation/anchors/<pack_id>"

    if p.contains("/ableton/racks/") {
      return "service: assets.export_racks anchors_pack=\(ap) overwrite=true"
    }
    if p.contains("/ableton/performance-sets/") {
      return "service: assets.export_performance_set anchors_pack=\(ap) overwrite=true"
    }
    if p.contains("/ableton/finishing-bays/") {
      return "service: assets.export_finishing_bays anchors_pack=\(ap) overwrite=true"
    }
    if p.contains("library/serum/") {
      return "service: assets.export_serum_base anchors_pack=\(ap) overwrite=true"
    }
    return "service: assets.export_all anchors_pack=\(ap) overwrite=true"
  }
}
