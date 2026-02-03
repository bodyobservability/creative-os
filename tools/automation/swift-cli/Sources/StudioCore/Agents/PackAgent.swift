import Foundation

struct PackAgent: CreativeOS.Agent {
  let pack: CreativeOS.PackManifest

  var id: String { "pack:\(pack.id)" }

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}
  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {}

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(pack.id),
      "applies_to": .array(pack.appliesTo.map { .string($0) }),
      "contents": .object(pack.contents),
      "requires_explicit_apply": .bool(pack.requiresExplicitApply)
    ])
    return CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: json)
  }

  func desiredState() throws -> CreativeOS.DesiredStateSlice? {
    let json: CreativeOS.JSONValue = .object([
      "id": .string(pack.id),
      "applies_to": .array(pack.appliesTo.map { .string($0) }),
      "contents": .object(pack.contents),
      "requires_explicit_apply": .bool(pack.requiresExplicitApply)
    ])
    return CreativeOS.DesiredStateSlice(agentId: id, data: nil, raw: json)
  }
}
