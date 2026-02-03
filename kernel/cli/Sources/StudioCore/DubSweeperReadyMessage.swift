import Foundation
enum DubSweeperReadyMessage {
  static func printIfReady(report: DubSweeperReportV1) {
    guard report.status == .pass else { return }
    print("✅ Machine certified for studio automation.")
    print("Next:")
    print("  1) wub plan --spec <spec.yaml> --resolve <resolve_report.json>")
    print("  2) wub apply --plan runs/<run_id>/plan.v1.json --interactive")
    print("")
  }
  static func printIfNotReady(report: DubSweeperReportV1) {
    guard report.status != .pass else { return }
    print("Not ready to apply yet.")
    print("Fix blockers above, then rerun: wub sweep --anchors-pack <pack> --modal-test detect")
    print("")
  }
}
