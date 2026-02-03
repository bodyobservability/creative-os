import XCTest
@testable import StudioCore

final class CreativeOSSetupReceiptTests: XCTestCase {
  func testSetupReceiptRoundTrip() throws {
    let runId = "2026-02-03_120000"
    let receipt = CreativeOSSetupReceiptV1(
      schemaVersion: 1,
      runId: runId,
      createdAt: "2026-02-03T12:00:00Z",
      status: "dry_run",
      apply: false,
      allowlist: ["ready.check"],
      planSteps: [
        .init(stepId: "ready_check", agent: "ready", actionId: "ready.check")
      ],
      executedSteps: [],
      skippedSteps: [
        .init(stepId: "drift_check", agent: "drift", actionId: "drift.check", reason: "action not allowlisted (drift.check)")
      ],
      manualSteps: [
        .init(stepId: "index_status", agent: "index", actionId: nil)
      ],
      failures: []
    )

    let tmpDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
    let outPath = tmpDir.appendingPathComponent("creative_os_setup_receipt.v1.json")

    try JSONIO.save(receipt, to: outPath)
    let decoded = try JSONIO.load(CreativeOSSetupReceiptV1.self, from: outPath)

    XCTAssertEqual(decoded.runId, runId)
    XCTAssertEqual(decoded.status, "dry_run")
    XCTAssertEqual(decoded.planSteps.first?.actionId, "ready.check")
    XCTAssertEqual(decoded.manualSteps.first?.actionId, nil)
    XCTAssertEqual(decoded.skippedSteps.first?.reason, "action not allowlisted (drift.check)")
  }
}
