import Foundation

extension CreativeOS {
  protocol Agent {
    var id: String { get }
    func registerChecks(_ r: inout CheckRegistry)
    func registerPlans(_ p: inout PlanRegistry)
    func observeState() throws -> ObservedStateSlice
  }

  struct CheckRegistry {
    private(set) var entries: [CheckRegistration] = []

    mutating func register(id: String, _ run: @escaping () throws -> CheckResult) {
      entries.append(CheckRegistration(id: id, run: run))
    }
  }

  struct CheckRegistration {
    let id: String
    let run: () throws -> CheckResult
  }

  struct PlanRegistry {
    private(set) var entries: [PlanRegistration] = []

    mutating func register(id: String, _ run: @escaping () throws -> [PlanStep]) {
      entries.append(PlanRegistration(id: id, run: run))
    }
  }

  struct PlanRegistration {
    let id: String
    let run: () throws -> [PlanStep]
  }

  struct SweepReport: Codable {
    let observed: ObservedState
    let desired: DesiredState
    let checks: [CheckResult]

    enum CodingKeys: String, CodingKey {
      case observed = "observed_state"
      case desired = "desired_state"
      case checks
    }
  }

  struct PlanReport: Codable {
    let observed: ObservedState
    let desired: DesiredState
    let steps: [PlanStep]

    enum CodingKeys: String, CodingKey {
      case observed = "observed_state"
      case desired = "desired_state"
      case steps
    }
  }

  enum StateMergeError: Error, CustomStringConvertible {
    case duplicateAgentId(String)

    var description: String {
      switch self {
      case .duplicateAgentId(let agentId):
        return "duplicate agent_id '\(agentId)' in state slices"
      }
    }
  }

  struct Runtime {
    let agents: [Agent]
    let profile: Profile?

    init(agents: [Agent], profile: Profile? = nil) {
      self.agents = agents
      self.profile = profile
    }

    func sweep() throws -> SweepReport {
      let observed = try observeState()
      let desired = desiredState()
      let checks = try evaluateChecks()
      return SweepReport(observed: observed, desired: desired, checks: checks)
    }

    func plan() throws -> PlanReport {
      let sweep = try sweep()
      let steps = diff(observed: sweep.observed, desired: sweep.desired)
      return PlanReport(observed: sweep.observed, desired: sweep.desired, steps: steps)
    }

    private func observeState() throws -> ObservedState {
      let slices = try agents.map { try $0.observeState() }
      return try mergeObserved(slices)
    }

    private func desiredState() -> DesiredState {
      var slices: [DesiredStateSlice] = []
      if let profile {
        slices.append(profileSlice(from: profile))
      }
      return DesiredState(slices: slices)
    }

    private func evaluateChecks() throws -> [CheckResult] {
      var registry = CheckRegistry()
      for agent in agents { agent.registerChecks(&registry) }
      var results: [CheckResult] = []
      for entry in registry.entries {
        results.append(try entry.run())
      }
      return results.sorted { ($0.agent, $0.id) < ($1.agent, $1.id) }
    }

    private func diff(observed: ObservedState, desired: DesiredState) -> [PlanStep] {
      let observedByAgent = Dictionary(uniqueKeysWithValues: observed.slices.map { ($0.agentId, $0) })
      let desiredSorted = desired.slices.sorted { $0.agentId < $1.agentId }
      var steps: [PlanStep] = []

      for desiredSlice in desiredSorted {
        guard let observedSlice = observedByAgent[desiredSlice.agentId] else {
          steps.append(PlanStep(id: "state_missing_\(desiredSlice.agentId)",
                                agent: desiredSlice.agentId,
                                type: .manualRequired,
                                description: "Provide observed state slice for agent \(desiredSlice.agentId)",
                                effects: [],
                                idempotent: true,
                                manualReason: "observed_state_missing"))
          continue
        }
        if !stateMatches(observed: observedSlice, desired: desiredSlice) {
          steps.append(PlanStep(id: "state_mismatch_\(desiredSlice.agentId)",
                                agent: desiredSlice.agentId,
                                type: .manualRequired,
                                description: "Align observed state for agent \(desiredSlice.agentId) with desired policy",
                                effects: [],
                                idempotent: true,
                                manualReason: "state_diff"))
        }
      }

      return steps.sorted { ($0.agent, $0.id) < ($1.agent, $1.id) }
    }

    private func stateMatches(observed: ObservedStateSlice, desired: DesiredStateSlice) -> Bool {
      if observed.agentId != desired.agentId { return false }
      if observed.data != desired.data { return false }
      if observed.raw != desired.raw { return false }
      return true
    }

    private func mergeObserved(_ slices: [ObservedStateSlice]) throws -> ObservedState {
      var seen = Set<String>()
      for slice in slices {
        if seen.contains(slice.agentId) { throw StateMergeError.duplicateAgentId(slice.agentId) }
        seen.insert(slice.agentId)
      }
      return ObservedState(slices: slices)
    }

    private func profileSlice(from profile: Profile) -> DesiredStateSlice {
      let json: JSONValue = .object([
        "id": .string(profile.id),
        "intents": .array(profile.intents.map { .string($0) }),
        "policies": .object(profile.policies),
        "requirements": .object(profile.requirements),
        "packs": .array(profile.packs.map { .string($0) })
      ])
      return DesiredStateSlice(agentId: "profile", data: nil, raw: json)
    }
  }

  struct NullAgent: Agent {
    let id: String = "null"
    func registerChecks(_ r: inout CheckRegistry) {}
    func registerPlans(_ p: inout PlanRegistry) {}
    func observeState() throws -> ObservedStateSlice {
      ObservedStateSlice(agentId: id, data: nil, raw: nil)
    }
  }

  enum Smoke {
    static func run() throws -> PlanReport {
      let runtime = Runtime(agents: [NullAgent()])
      return try runtime.plan()
    }
  }
}
