import Foundation

enum CreativeOS {
  enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if container.decodeNil() { self = .null; return }
      if let value = try? container.decode(Bool.self) { self = .bool(value); return }
      if let value = try? container.decode(Int.self) { self = .number(Double(value)); return }
      if let value = try? container.decode(Double.self) { self = .number(value); return }
      if let value = try? container.decode(String.self) { self = .string(value); return }
      if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
      if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch self {
      case .string(let value): try container.encode(value)
      case .number(let value): try container.encode(value)
      case .bool(let value): try container.encode(value)
      case .object(let value): try container.encode(value)
      case .array(let value): try container.encode(value)
      case .null: try container.encodeNil()
      }
    }
  }

  enum CheckSeverity: String, Codable { case pass, warn, fail }
  enum CheckCategory: String, Codable { case audio, plugin, midi, filesystem, policy, ui, automation, runtime }

  struct ActionRef: Codable {
    let id: String
    let kind: ActionRefKind
    let description: String?
  }

  enum ActionRefKind: String, Codable { case setup, repair, recheck, open, docs, manual }

  struct Effect: Codable {
    let id: String
    let kind: EffectKind
    let target: String
    let description: String?
  }

  enum EffectKind: String, Codable { case filesystem, config, device, process, ui }

  struct EvidenceItem: Codable {
    let id: String
    let kind: String
    let path: String?
    let details: JSONValue?
  }

  struct CheckResult: Codable {
    let id: String
    let agent: String
    var severity: CheckSeverity
    var category: CheckCategory
    var observed: JSONValue?
    var expected: JSONValue?
    var evidence: [EvidenceItem]
    var suggestedActions: [ActionRef]

    enum CodingKeys: String, CodingKey {
      case id
      case agent
      case severity
      case category
      case observed
      case expected
      case evidence
      case suggestedActions = "suggested_actions"
    }

    init(id: String,
         agent: String,
         severity: CheckSeverity = .warn,
         category: CheckCategory = .runtime,
         observed: JSONValue? = nil,
         expected: JSONValue? = nil,
         evidence: [EvidenceItem] = [],
         suggestedActions: [ActionRef] = []) {
      self.id = id
      self.agent = agent
      self.severity = severity
      self.category = category
      self.observed = observed
      self.expected = expected
      self.evidence = evidence
      self.suggestedActions = suggestedActions
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(String.self, forKey: .id)
      agent = try container.decode(String.self, forKey: .agent)
      severity = try container.decodeIfPresent(CheckSeverity.self, forKey: .severity) ?? .warn
      category = try container.decodeIfPresent(CheckCategory.self, forKey: .category) ?? .runtime
      observed = try container.decodeIfPresent(JSONValue.self, forKey: .observed)
      expected = try container.decodeIfPresent(JSONValue.self, forKey: .expected)
      evidence = try container.decodeIfPresent([EvidenceItem].self, forKey: .evidence) ?? []
      suggestedActions = try container.decodeIfPresent([ActionRef].self, forKey: .suggestedActions) ?? []
    }
  }

  enum PlanStepType: String, Codable { case automated, manualRequired = "manual_required" }

  struct PlanStep: Codable {
    let id: String
    let agent: String
    var type: PlanStepType
    let description: String
    var effects: [Effect]
    var idempotent: Bool
    let manualReason: String?

    enum CodingKeys: String, CodingKey {
      case id
      case agent
      case type
      case description
      case effects
      case idempotent
      case manualReason = "manual_reason"
    }

    init(id: String,
         agent: String,
         type: PlanStepType = .manualRequired,
         description: String,
         effects: [Effect] = [],
         idempotent: Bool = true,
         manualReason: String? = nil) {
      self.id = id
      self.agent = agent
      self.type = type
      self.description = description
      self.effects = effects
      self.idempotent = idempotent
      self.manualReason = manualReason
    }

    init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(String.self, forKey: .id)
      agent = try container.decode(String.self, forKey: .agent)
      type = try container.decodeIfPresent(PlanStepType.self, forKey: .type) ?? .manualRequired
      description = try container.decode(String.self, forKey: .description)
      effects = try container.decodeIfPresent([Effect].self, forKey: .effects) ?? []
      idempotent = try container.decodeIfPresent(Bool.self, forKey: .idempotent) ?? true
      manualReason = try container.decodeIfPresent(String.self, forKey: .manualReason)
      if type == .manualRequired && (manualReason == nil || manualReason?.isEmpty == true) {
        throw DecodingError.dataCorruptedError(forKey: .manualReason, in: container, debugDescription: "manual_reason is required when type=manual_required")
      }
    }
  }

  struct ObservedState: Codable {
    let slices: [ObservedStateSlice]
  }

  struct DesiredState: Codable {
    let slices: [DesiredStateSlice]
  }

  struct ObservedStateSlice: Codable {
    let agentId: String
    let data: [String: JSONValue]?
    let raw: JSONValue?

    enum CodingKeys: String, CodingKey {
      case agentId = "agent_id"
      case data
      case raw
    }
  }

  struct DesiredStateSlice: Codable {
    let agentId: String
    let data: [String: JSONValue]?
    let raw: JSONValue?

    enum CodingKeys: String, CodingKey {
      case agentId = "agent_id"
      case data
      case raw
    }
  }

  struct Profile: Codable {
    let id: String
    let intents: [String]
    let policies: [String: JSONValue]
    let requirements: [String: JSONValue]
    let packs: [String]
  }

  struct PackManifest: Codable {
    let id: String
    let appliesTo: [String]
    let contents: [String: JSONValue]
    let requiresExplicitApply: Bool

    enum CodingKeys: String, CodingKey {
      case id
      case appliesTo = "applies_to"
      case contents
      case requiresExplicitApply = "requires_explicit_apply"
    }
  }

  struct ServiceResult {
    let observed: ObservedStateSlice?
    let desired: DesiredStateSlice?
    let checks: [CheckResult]
    let steps: [PlanStep]

    init(observed: ObservedStateSlice? = nil,
         desired: DesiredStateSlice? = nil,
         checks: [CheckResult] = [],
         steps: [PlanStep] = []) {
      self.observed = observed
      self.desired = desired
      self.checks = checks
      self.steps = steps
    }
  }
}
