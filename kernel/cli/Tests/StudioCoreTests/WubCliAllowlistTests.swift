import XCTest
@testable import StudioCore

final class WubCliAllowlistTests: XCTestCase {
  func testEvaluateSetupStepsUsesAllowlistAndSupport() {
    let allowlist: Set<String> = ["ready.check"]
    let steps: [CreativeOS.PlanStep] = [
      CreativeOS.PlanStep(id: "manual_step",
                          agent: "test",
                          type: .manualRequired,
                          description: "Manual step",
                          actionRef: nil),
      CreativeOS.PlanStep(id: "ready_check",
                          agent: "test",
                          type: .automated,
                          description: "Ready check",
                          actionRef: .init(id: "ready.check", kind: .setup, description: nil)),
      CreativeOS.PlanStep(id: "not_allowlisted",
                          agent: "test",
                          type: .automated,
                          description: "Not allowlisted",
                          actionRef: .init(id: "unknown.allowed", kind: .setup, description: nil))
    ]

    let evaluation = evaluateSetupSteps(steps, allowlist: allowlist)

    XCTAssertEqual(evaluation.manual.count, 1)
    XCTAssertEqual(evaluation.executable.count, 1)
    XCTAssertEqual(evaluation.skipped.count, 1)

    let skippedById = Dictionary(uniqueKeysWithValues: evaluation.skipped.map {
      ($0.0.actionRef?.id ?? "", $0.1)
    })

    XCTAssertEqual(skippedById["unknown.allowed"], "action not allowlisted (unknown.allowed)")
  }
}
