import Foundation

extension CreativeOS {
  enum CheckSetError: Error, CustomStringConvertible {
    case duplicateCheckKey(String)

    var description: String {
      switch self {
      case .duplicateCheckKey(let key):
        return "duplicate check key '\(key)' (expected unique agent/id per sweep)"
      }
    }
  }

  protocol Agent {
    var id: String { get }
    func registerChecks(_ r: inout CheckRegistry)
    func registerPlans(_ p: inout PlanRegistry)
    func observeState() throws -> ObservedStateSlice
    func desiredState() throws -> DesiredStateSlice?
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
      let checks = try evaluateChecks(observed: observed, desired: desired)
      return SweepReport(observed: observed, desired: desired, checks: checks)
    }

    func plan() throws -> PlanReport {
      let sweep = try sweep()
      var steps = diff(observed: sweep.observed, desired: sweep.desired)
      var registry = PlanRegistry()
      for agent in agents { agent.registerPlans(&registry) }
      for entry in registry.entries {
        steps.append(contentsOf: try entry.run())
      }
      let ordered = steps.sorted { ($0.agent, $0.id) < ($1.agent, $1.id) }
      return PlanReport(observed: sweep.observed, desired: sweep.desired, steps: ordered)
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
      for agent in agents {
        if let slice = try? agent.desiredState() {
          slices.append(slice)
        }
      }
      return DesiredState(slices: slices)
    }

    private func evaluateChecks(observed: ObservedState, desired: DesiredState) throws -> [CheckResult] {
      var registry = CheckRegistry()
      for agent in agents { agent.registerChecks(&registry) }
      var results: [CheckResult] = []
      for entry in registry.entries {
        results.append(try entry.run())
      }
      results.append(contentsOf: mismatchChecks(observed: observed, desired: desired))
      try enforceUniqueCheckKeys(results)
      return results.sorted(by: checkOrder)
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
        _ = observedSlice
      }

      return steps.sorted { ($0.agent, $0.id) < ($1.agent, $1.id) }
    }

    private func stateMatches(observed: ObservedStateSlice, desired: DesiredStateSlice) -> Bool {
      if observed.agentId != desired.agentId { return false }
      if observed.data != desired.data { return false }
      if observed.raw != desired.raw { return false }
      return true
    }

    private func mismatchChecks(observed: ObservedState, desired: DesiredState) -> [CheckResult] {
      let observedByAgent = Dictionary(uniqueKeysWithValues: observed.slices.map { ($0.agentId, $0) })
      let desiredSorted = desired.slices.sorted { $0.agentId < $1.agentId }
      var results: [CheckResult] = []

      for desiredSlice in desiredSorted {
        guard let observedSlice = observedByAgent[desiredSlice.agentId] else {
          results.append(CheckResult(id: "state_missing_\(desiredSlice.agentId)",
                                     agent: desiredSlice.agentId,
                                     severity: .warn,
                                     category: .policy,
                                     observed: nil,
                                     expected: slicePayload(desiredSlice),
                                     evidence: [],
                                     suggestedActions: mismatchSuggestedActions(agentId: desiredSlice.agentId,
                                                                              kind: "observed_state_missing")))
          continue
        }
        if !stateMatches(observed: observedSlice, desired: desiredSlice) {
          results.append(CheckResult(id: "state_mismatch_\(desiredSlice.agentId)",
                                     agent: desiredSlice.agentId,
                                     severity: .warn,
                                     category: .policy,
                                     observed: slicePayload(observedSlice),
                                     expected: slicePayload(desiredSlice),
                                     evidence: [],
                                     suggestedActions: mismatchSuggestedActions(agentId: desiredSlice.agentId,
                                                                              kind: "observed_state_mismatch")))
        }
      }

      return results
    }

    private func slicePayload(_ slice: ObservedStateSlice) -> JSONValue? {
      if let raw = slice.raw { return raw }
      if let data = slice.data { return .object(data) }
      return nil
    }

    private func slicePayload(_ slice: DesiredStateSlice) -> JSONValue? {
      if let raw = slice.raw { return raw }
      if let data = slice.data { return .object(data) }
      return nil
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

    // MARK: - Check ordering + uniqueness

    private func enforceUniqueCheckKeys(_ results: [CheckResult]) throws {
      var seen = Set<String>()
      for result in results {
        let key = "\(result.agent)/\(result.id)"
        if seen.contains(key) { throw CheckSetError.duplicateCheckKey(key) }
        seen.insert(key)
      }
    }

    private func severityRank(_ severity: CheckSeverity) -> Int {
      switch severity {
      case .fail: return 0
      case .warn: return 1
      case .pass: return 2
      }
    }

    private func checkOrder(_ lhs: CheckResult, _ rhs: CheckResult) -> Bool {
      let lhsRank = severityRank(lhs.severity)
      let rhsRank = severityRank(rhs.severity)
      if lhsRank != rhsRank { return lhsRank < rhsRank }
      if lhs.agent != rhs.agent { return lhs.agent < rhs.agent }
      return lhs.id < rhs.id
    }

    // MARK: - Minimal suggested actions for mismatch checks

    private func mismatchSuggestedActions(agentId: String, kind: String) -> [ActionRef] {
      let docs = ActionRef(
        id: "docs.\(agentId).\(kind)",
        kind: .docs,
        description: "Review runbook for \(agentId) (\(kind))"
      )
      let open = ActionRef(
        id: "open.\(agentId).state",
        kind: .open,
        description: "Open state details for \(agentId)"
      )
      return [docs, open]
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

extension CreativeOS.Agent {
  func desiredState() throws -> CreativeOS.DesiredStateSlice? { nil }
}
