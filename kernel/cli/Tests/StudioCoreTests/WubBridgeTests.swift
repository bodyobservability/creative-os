import XCTest
@testable import StudioCore

final class WubBridgeTests: XCTestCase {
  private func loadFixture<T: Decodable>(_ type: T.Type, name: String) throws -> T {
    let url = Bundle.module.url(forResource: name, withExtension: "json")
    XCTAssertNotNil(url, "Missing fixture: \(name).json")
    return try JSONDecoder().decode(T.self, from: Data(contentsOf: url!))
  }

  func testSweepBridgeDeterministicOrdering() throws {
    let sweeper: DubSweeperReportV1 = try loadFixture(DubSweeperReportV1.self, name: "sweeper_report.v1")
    let ready: ReadyReportV1 = try loadFixture(ReadyReportV1.self, name: "ready_report.v1")
    let drift: DriftReportV2 = try loadFixture(DriftReportV2.self, name: "drift_report.v2")

    var checks: [CreativeOS.CheckResult] = []
    checks.append(contentsOf: CreativeOSBridge.checkResults(from: sweeper))
    checks.append(contentsOf: CreativeOSBridge.checkResults(from: ready))
    checks.append(contentsOf: CreativeOSBridge.checkResults(from: drift))

    let ordered = checks.sorted { ($0.agent, $0.id) < ($1.agent, $1.id) }
    let ids = ordered.map { "\($0.agent)/\($0.id)" }

    XCTAssertEqual(ids, [
      "drift/artifact_1",
      "ready/anchors_pack_path_exists",
      "ready/artifact_index_present",
      "sweeper/ableton_liveness",
      "sweeper/controllers"
    ])

    XCTAssertEqual(ordered.first?.severity, .fail)
    XCTAssertEqual(ordered.first?.category, .filesystem)
  }

  func testPlanBridgeDeterministicOrdering() throws {
    let ready: ReadyReportV1 = try loadFixture(ReadyReportV1.self, name: "ready_report.v1")
    let drift: DriftReportV2 = try loadFixture(DriftReportV2.self, name: "drift_report.v2")

    var steps: [CreativeOS.PlanStep] = []
    steps.append(contentsOf: CreativeOSBridge.planSteps(from: ready))
    steps.append(contentsOf: CreativeOSBridge.planSteps(from: drift))

    let ordered = steps.sorted { ($0.agent, $0.id) < ($1.agent, $1.id) }
    let ids = ordered.map { "\($0.agent)/\($0.id)" }

    XCTAssertEqual(ids, [
      "drift/fix_1",
      "ready/ready_command_1",
      "ready/ready_command_2"
    ])

    XCTAssertEqual(ordered.first?.type, .manualRequired)
    XCTAssertEqual(ordered.first?.manualReason, "recommended_fix")
  }
}
