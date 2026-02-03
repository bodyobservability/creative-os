import Foundation

struct MappingAgent: CreativeOS.Agent {
  let id: String = "runtime"

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
    let issues = CreativeOSMapping.validate()
    guard !issues.isEmpty else { return }
    r.register(id: "migration_mapping_validation") {
      CreativeOS.CheckResult(id: "migration_mapping_validation",
                             agent: id,
                             severity: .warn,
                             category: .policy,
                             observed: .array(issues.map { .string($0) }),
                             expected: nil,
                             evidence: [],
                             suggestedActions: [])
    }
  }

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let issues = CreativeOSMapping.validate()
    guard !issues.isEmpty else { return }
    p.register(id: "migration_mapping_validation") {
      [CreativeOS.PlanStep(id: "migration_mapping_validation",
                           agent: id,
                           type: .manualRequired,
                           description: "Resolve migration mapping validation issues",
                           effects: [],
                           idempotent: true,
                           manualReason: "mapping_validation")]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
