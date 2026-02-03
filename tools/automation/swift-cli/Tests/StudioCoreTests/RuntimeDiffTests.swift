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
}
