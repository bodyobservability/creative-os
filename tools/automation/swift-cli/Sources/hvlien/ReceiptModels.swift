import Foundation

struct ReceiptV1: Codable {
  let schemaVersion: Int
  let runId: String
  let planPath: String
  var status: String
  let startedAt: String
  var finishedAt: String?
  let actuator: ActuatorInfo
  var ops: [ReceiptOp]
  var failures: [ReceiptFailure]
  enum CodingKeys: String, CodingKey {
    case schemaVersion = "schema_version", runId = "run_id", planPath = "plan_path", status
    case startedAt = "started_at", finishedAt = "finished_at", actuator, ops, failures
  }
}

struct ActuatorInfo: Codable { let type: String; let device: String? }

struct ReceiptOp: Codable {
  let opId: String
  let attempts: Int
  let result: String
  let durationMs: Int
  let notes: String?
  enum CodingKeys: String, CodingKey { case opId = "op_id"; case attempts, result; case durationMs = "duration_ms"; case notes }
}

struct ReceiptFailure: Codable {
  let opId: String
  let attempts: Int
  let result: String
  let reason: String
  let artifactsDir: String
  enum CodingKeys: String, CodingKey { case opId = "op_id"; case attempts, result, reason; case artifactsDir = "artifacts_dir" }
}

final class ReceiptWriter {
  private(set) var receipt: ReceiptV1
  private let outURL: URL

  init(runId: String, planPath: String, actuator: ActuatorInfo, outURL: URL) {
    self.outURL = outURL
    self.receipt = ReceiptV1(schemaVersion: 1, runId: runId, planPath: planPath, status: "aborted",
                             startedAt: ISO8601DateFormatter().string(from: Date()), finishedAt: nil,
                             actuator: actuator, ops: [], failures: [])
  }

  func recordOp(opId: String, attempts: Int, result: String, durationMs: Int, notes: String? = nil) {
    receipt.ops.append(ReceiptOp(opId: opId, attempts: attempts, result: result, durationMs: durationMs, notes: notes))
  }

  func recordFailure(opId: String, attempts: Int, reason: String, artifactsDir: String) {
    receipt.failures.append(ReceiptFailure(opId: opId, attempts: attempts, result: "failed", reason: reason, artifactsDir: artifactsDir))
  }

  func finalize(status: String) {
    receipt.status = status
    receipt.finishedAt = ISO8601DateFormatter().string(from: Date())
  }

  func flush() { try? JSONIO.save(receipt, to: outURL) }
}
