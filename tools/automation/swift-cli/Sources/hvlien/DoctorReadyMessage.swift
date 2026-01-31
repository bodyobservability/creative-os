import Foundation
enum DoctorReadyMessage {
  static func printIfReady(report: DoctorReportV1) {
    guard report.status == .pass else { return }
    print("✅ Machine certified for HVLIEN automation.")
    print("Next:")
    print("  1) hvlien plan --spec <spec.yaml> --resolve <resolve_report.json>")
    print("  2) hvlien apply --plan runs/<run_id>/plan.v1.json --interactive")
    print("")
  }
  static func printIfNotReady(report: DoctorReportV1) {
    guard report.status != .pass else { return }
    print("Not ready to apply yet.")
    print("Fix blockers above, then rerun: hvlien doctor --anchors-pack <pack> --modal-test detect")
    print("")
  }
}
