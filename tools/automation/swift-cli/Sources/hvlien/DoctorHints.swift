import Foundation
enum DoctorHints {
  static func nextActions(from report: DoctorReportV1) -> [String] {
    let priority = ["regions_sanity","ableton_liveness","anchors_validation","modal_guard","controllers"]
    let fails = report.checks.filter { $0.status == .fail }
      .sorted { (a,b) in (priority.firstIndex(of: a.id) ?? 999) < (priority.firstIndex(of: b.id) ?? 999) }
    var out: [String] = []
    for f in fails { out.append(contentsOf: actions(for: f)) }
    var seen = Set<String>()
    return out.filter { seen.insert($0).inserted }
  }
  static func actions(for entry: DoctorCheckEntry) -> [String] {
    let d = entry.details
    switch entry.id {
    case "regions_sanity":
      let missing = d["missing"] ?? ""
      return ["Run: hvlien calibrate-regions", missing.isEmpty ? "Ensure regions.v1.json matches display/layout." : "Add missing regions: \(missing)"]
    case "ableton_liveness":
      let reason = d["reason"] ?? ""
      if reason.contains("browser.search") { return ["In Ableton: show Browser and search field.", "Rerun: hvlien doctor"] }
      if reason.contains("tracks.list") { return ["Show track headers; maximize Ableton.", "Rerun: hvlien doctor"] }
      if reason.contains("device.chain") { return ["Open Device View (Cmd+Opt+L).", "Rerun: hvlien doctor"] }
      if reason.contains("modal") { return ["Close dialog or run: hvlien doctor --fix", "Rerun: hvlien doctor"] }
      return ["Open Ableton and rerun: hvlien doctor"]
    case "anchors_validation":
      return ["Build OpenCV-enabled CLI (see V4_BUILD_OPENCV.md).", "Run: hvlien validate-anchors --pack <pack>", "Recapture/mask anchors with score < 0.90."]
    case "modal_guard":
      return ["If a dialog is open: run hvlien doctor --fix --modal-test active"]
    case "controllers":
      let miss = d["missing_required"] ?? ""
      if !miss.isEmpty { return ["Connect required controllers: \(miss)", "Rerun: hvlien doctor"] }
      return ["Controllers OK."]
    default: return []
    }
  }
}
