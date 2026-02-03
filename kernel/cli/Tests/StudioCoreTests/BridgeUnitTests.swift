import XCTest
@testable import StudioCore

final class BridgeUnitTests: XCTestCase {
  func testSeverityMapping() {
    let sweeper = DubSweeperReportV1(schemaVersion: 1,
                                runId: "r",
                                timestamp: "t",
                                status: .pass,
                                checks: [
                                  DubSweeperCheckEntry(id: "a", status: .pass, details: [:], artifacts: []),
                                  DubSweeperCheckEntry(id: "b", status: .fail, details: [:], artifacts: []),
                                  DubSweeperCheckEntry(id: "c", status: .skip, details: [:], artifacts: [])
                                ],
                                safeSteps: [],
                                manualSteps: [],
                                artifactsDir: "artifacts")
    let checks = CreativeOSBridge.checkResults(from: sweeper)
    XCTAssertEqual(checks.map { $0.severity }, [.pass, .fail, .warn])

    let drift = DriftReportV2(schemaVersion: 2,
                              runId: "r",
                              timestamp: "t",
                              status: "warn",
                              summary: "",
                              findings: [
                                DriftReportV2.Finding(id: "f1", severity: "info", kind: "unknown", artifactPath: "p", title: "t", why: "w", fix: "f", details: nil)
                              ],
                              reasons: [],
                              recommendedFixes: [])
    let driftChecks = CreativeOSBridge.checkResults(from: drift)
    XCTAssertEqual(driftChecks.first?.severity, .warn)
  }
}
