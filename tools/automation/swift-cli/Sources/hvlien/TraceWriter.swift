import Foundation

final class TraceWriter {
  private(set) var trace: TraceV1
  private let start = Date()
  private let outURL: URL

  init(runId: String, outURL: URL) {
    self.outURL = outURL
    self.trace = TraceV1(schemaVersion: 1, runId: runId, startedAt: ISO8601DateFormatter().string(from: Date()), ops: [])
  }

  func beginOp(_ opId: String) {
    if !trace.ops.contains(where: { $0.opId == opId }) {
      trace.ops.append(TraceOp(opId: opId, attempts: []))
    }
  }

  func beginAttempt(opId: String, attemptIndex: Int) {
    guard let idx = trace.ops.firstIndex(where: { $0.opId == opId }) else { return }
    trace.ops[idx].attempts.append(TraceAttempt(attemptIndex: attemptIndex, startedAt: ISO8601DateFormatter().string(from: Date()), events: [], result: "retry"))
  }

  func event(opId: String, attemptIndex: Int, kind: String, name: String, details: [String: String] = [:]) {
    guard let oi = trace.ops.firstIndex(where: { $0.opId == opId }) else { return }
    guard let ai = trace.ops[oi].attempts.firstIndex(where: { $0.attemptIndex == attemptIndex }) else { return }
    let ms = Int(Date().timeIntervalSince(start) * 1000.0)
    trace.ops[oi].attempts[ai].events.append(TraceEvent(tMs: ms, kind: kind, name: name, details: details))
  }

  func endAttempt(opId: String, attemptIndex: Int, result: String) {
    guard let oi = trace.ops.firstIndex(where: { $0.opId == opId }) else { return }
    guard let ai = trace.ops[oi].attempts.firstIndex(where: { $0.attemptIndex == attemptIndex }) else { return }
    trace.ops[oi].attempts[ai].result = result
  }

  func flush() { try? JSONIO.save(trace, to: outURL) }
}
