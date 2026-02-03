import Foundation

struct CreativeOSSetupReceiptV1: Codable {
  struct StepRef: Codable {
    let stepId: String
    let agent: String
    let actionId: String?

    enum CodingKeys: String, CodingKey {
      case stepId = "step_id"
      case agent
      case actionId = "action_id"
    }
  }

  struct ExecutedStep: Codable {
    let stepId: String
    let agent: String
    let actionId: String
    let status: String
    let exitCode: Int?
    let error: String?
    let startedAt: String
    let finishedAt: String

    enum CodingKeys: String, CodingKey {
      case stepId = "step_id"
      case agent
      case actionId = "action_id"
      case status
      case exitCode = "exit_code"
      case error
      case startedAt = "started_at"
      case finishedAt = "finished_at"
    }
  }

  struct SkippedStep: Codable {
    let stepId: String
    let agent: String
    let actionId: String?
    let reason: String

    enum CodingKeys: String, CodingKey {
      case stepId = "step_id"
      case agent
      case actionId = "action_id"
      case reason
    }
  }

  let schemaVersion: Int
  let runId: String
  let createdAt: String
  let status: String
  let apply: Bool
  let allowlist: [String]
  let planSteps: [StepRef]
  let executedSteps: [ExecutedStep]
  let skippedSteps: [SkippedStep]
  let manualSteps: [StepRef]
  let failures: [String]

  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version"
    case runId = "run_id"
    case createdAt = "created_at"
    case status
    case apply
    case allowlist
    case planSteps = "plan_steps"
    case executedSteps = "executed_steps"
    case skippedSteps = "skipped_steps"
    case manualSteps = "manual_steps"
    case failures
  }
}
