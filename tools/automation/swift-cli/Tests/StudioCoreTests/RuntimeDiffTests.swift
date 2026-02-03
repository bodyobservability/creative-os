import XCTest
@testable import StudioCore

final class RuntimeDiffTests: XCTestCase {
  struct ProfileAgent: CreativeOS.Agent {
    let id: String
    let slice: CreativeOS.ObservedStateSlice
    func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}
    func registerPlans(_ p: inout CreativeOS.PlanRegistry) {}
    func observeState() throws -> CreativeOS.ObservedStateSlice { slice }
  }

  struct CheckAgent: CreativeOS.Agent {
    let id: String
    let slice: CreativeOS.ObservedStateSlice
    let checks: [CreativeOS.CheckResult]

    func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
      for (idx, check) in checks.enumerated() {
        r.register(id: "\(id)_\(idx)") { check }
      }
    }

    func registerPlans(_ p: inout CreativeOS.PlanRegistry) {}
    func observeState() throws -> CreativeOS.ObservedStateSlice { slice }
  }

  func testNoPlanWhenStateMatches() throws {
    let profile = CreativeOS.Profile(id: "hvlien",
                                     intents: [],
                                     policies: [:],
                                     requirements: [:],
                                     packs: [])
    let json: CreativeOS.JSONValue = .object([
      "id": .string("hvlien"),
      "intents": .array([]),
      "policies": .object([:]),
      "requirements": .object([:]),
      "packs": .array([])
    ])
    let agent = ProfileAgent(id: "profile",
                             slice: CreativeOS.ObservedStateSlice(agentId: "profile", data: nil, raw: json))
    let runtime = CreativeOS.Runtime(agents: [agent], profile: profile)
    let plan = try runtime.plan()
    XCTAssertTrue(plan.steps.isEmpty)
  }

  func testPlanWhenStateDiffers() throws {
    let profile = CreativeOS.Profile(id: "hvlien",
                                     intents: [],
                                     policies: [:],
                                     requirements: [:],
                                     packs: [])
    let json: CreativeOS.JSONValue = .object([
      "id": .string("other"),
      "intents": .array([]),
      "policies": .object([:]),
      "requirements": .object([:]),
      "packs": .array([])
    ])
    let agent = ProfileAgent(id: "profile",
                             slice: CreativeOS.ObservedStateSlice(agentId: "profile", data: nil, raw: json))
    let runtime = CreativeOS.Runtime(agents: [agent], profile: profile)
    let sweep = try runtime.sweep()
    let plan = try runtime.plan()
    XCTAssertTrue(plan.steps.isEmpty)
    XCTAssertEqual(sweep.checks.count, 1)
    XCTAssertEqual(sweep.checks.first?.id, "state_mismatch_profile")
  }

  func testDuplicateCheckKeysThrow() {
    let slice = CreativeOS.ObservedStateSlice(agentId: "a", data: nil, raw: nil)
    let dup = CreativeOS.CheckResult(id: "dup", agent: "a", severity: .warn)
    let agent = CheckAgent(id: "a", slice: slice, checks: [dup, dup])
    let runtime = CreativeOS.Runtime(agents: [agent], profile: nil)

    XCTAssertThrowsError(try runtime.sweep()) { error in
      guard let checkError = error as? CreativeOS.CheckSetError else {
        XCTFail("Unexpected error: \(error)")
        return
      }
      switch checkError {
      case .duplicateCheckKey(let key):
        XCTAssertEqual(key, "a/dup")
      }
    }
  }

  func testChecksOrderedBySeverityThenAgentId() throws {
    let aSlice = CreativeOS.ObservedStateSlice(agentId: "a", data: nil, raw: nil)
    let bSlice = CreativeOS.ObservedStateSlice(agentId: "b", data: nil, raw: nil)

    let aChecks = [
      CreativeOS.CheckResult(id: "pass_check", agent: "a", severity: .pass),
      CreativeOS.CheckResult(id: "fail_check", agent: "a", severity: .fail)
    ]
    let bChecks = [
      CreativeOS.CheckResult(id: "warn_check", agent: "b", severity: .warn)
    ]

    let runtime = CreativeOS.Runtime(agents: [
      CheckAgent(id: "a", slice: aSlice, checks: aChecks),
      CheckAgent(id: "b", slice: bSlice, checks: bChecks)
    ], profile: nil)

    let sweep = try runtime.sweep()
    let ordered = sweep.checks.map { "\($0.severity.rawValue):\($0.agent)/\($0.id)" }

    XCTAssertEqual(ordered, [
      "fail:a/fail_check",
      "warn:b/warn_check",
      "pass:a/pass_check"
    ])
  }

  func testMismatchChecksHaveSuggestedActions() throws {
    let profile = CreativeOS.Profile(id: "hvlien",
                                     intents: [],
                                     policies: [:],
                                     requirements: [:],
                                     packs: [])
    let json: CreativeOS.JSONValue = .object([
      "id": .string("other"),
      "intents": .array([]),
      "policies": .object([:]),
      "requirements": .object([:]),
      "packs": .array([])
    ])
    let agent = ProfileAgent(id: "profile",
                             slice: CreativeOS.ObservedStateSlice(agentId: "profile", data: nil, raw: json))
    let runtime = CreativeOS.Runtime(agents: [agent], profile: profile)
    let sweep = try runtime.sweep()

    guard let mismatch = sweep.checks.first(where: { $0.id == "state_mismatch_profile" }) else {
      XCTFail("Expected state_mismatch_profile check")
      return
    }
    XCTAssertEqual(mismatch.suggestedActions.count, 2)
    XCTAssertEqual(mismatch.suggestedActions.first?.kind, .docs)
    XCTAssertEqual(mismatch.suggestedActions.last?.kind, .open)
  }
}
