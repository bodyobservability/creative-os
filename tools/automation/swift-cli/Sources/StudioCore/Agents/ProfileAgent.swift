import Foundation

struct ProfileAgent: CreativeOS.Agent {
  let id: String = "profile"
  let profile: CreativeOS.Profile

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}
  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {}

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(profile.id),
      "intents": .array(profile.intents.map { .string($0) }),
      "policies": .object(profile.policies),
      "requirements": .object(profile.requirements),
      "packs": .array(profile.packs.map { .string($0) })
    ])
    return CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: json)
  }
}
