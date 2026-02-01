import Foundation

enum StationGate {
  enum GateDecision: String { case allow, warn_force, refuse }

  struct GateResult {
    let decision: GateDecision
    let stationState: String
    let confidence: Double
    let reason: String
    let suggestedNext: [String]
  }

  /// v1.7.18: Evaluate station context by calling `wub station status --format json --no-write-report`.
  /// Falls back to conservative unknown if parsing fails.
  static func evaluate(anchorsPackHint: String?, force: Bool = false) -> GateResult {
    if let rep = readStationStatusJSON() {
      let state = rep.stationState
      let conf = rep.confidence

      // Hard refusals
      if state == "blocked" {
        return GateResult(decision: .refuse,
                          stationState: state,
                          confidence: conf,
                          reason: "station_status reports blocked (modal)",
                          suggestedNext: [
                            "Open failures folder (if present)",
                            "Clear modal dialogs, then rerun: wub station status --format json --no-write-report"
                          ])
      }
      if state == "exporting" {
        return GateResult(decision: .refuse,
                          stationState: state,
                          confidence: conf,
                          reason: "station_status reports exporting (save sheet/export in progress)",
                          suggestedNext: ["Wait for export to finish, then retry."])
      }
      if state == "performing" {
        return GateResult(decision: .refuse,
                          stationState: state,
                          confidence: conf,
                          reason: "station_status reports performing",
                          suggestedNext: [
                            "Stop playback/recording or set mode=studio",
                            "Then retry"
                          ])
      }

      if state == "unknown" {
        return GateResult(decision: .warn_force,
                          stationState: state,
                          confidence: conf,
                          reason: "station_status unknown",
                          suggestedNext: [
                            "Bring Ableton to front and clear dialogs, then retry",
                            "Or pass --force to proceed anyway"
                          ])
      }

      // Allow idle/editing
      return GateResult(decision: .allow,
                        stationState: state,
                        confidence: conf,
                        reason: "station_status reports safe state",
                        suggestedNext: [])
    }

    // Fallback: unknown
    return GateResult(decision: .warn_force,
                      stationState: "unknown",
                      confidence: 0.5,
                      reason: "could not read station status json",
      suggestedNext: [
                        "Run: wub station status --format human",
                        "Or pass --force to proceed anyway"
                      ])
  }

  static func enforceOrThrow(force: Bool, anchorsPackHint: String?, commandName: String) throws {
    let res = evaluate(anchorsPackHint: anchorsPackHint, force: force)
    switch res.decision {
    case .allow:
      return
    case .refuse:
      throw GateError.refused(commandName: commandName, state: res.stationState, reason: res.reason, next: res.suggestedNext)
    case .warn_force:
      if force { return }
      throw GateError.needsForce(commandName: commandName, state: res.stationState, reason: res.reason, next: res.suggestedNext)
    }
  }

  enum GateError: LocalizedError {
    case refused(commandName: String, state: String, reason: String, next: [String])
    case needsForce(commandName: String, state: String, reason: String, next: [String])

    var errorDescription: String? {
      switch self {
      case let .refused(cmd, state, reason, next):
        return format(kind: "Refusing", cmd: cmd, state: state, reason: reason, next: next, forceHint: false)
      case let .needsForce(cmd, state, reason, next):
        return format(kind: "Unsafe without --force", cmd: cmd, state: state, reason: reason, next: next, forceHint: true)
      }
    }

    private func format(kind: String, cmd: String, state: String, reason: String, next: [String], forceHint: Bool) -> String {
      var s = "\(kind): \(cmd) (station_state=\(state))\nWhy: \(reason)\n"
      if !next.isEmpty {
        s += "Next:\n"
        for n in next { s += "- \(n)\n" }
      }
      if forceHint { s += "To override: rerun with --force\n" }
      return s
    }
  }

  // MARK: station status JSON reader

  private struct StationStatusEnvelope: Decodable {
    let stationState: String
    let confidence: Double
    enum CodingKeys: String, CodingKey {
      case stationState = "station_state"
      case confidence
    }
  }

  private static func readStationStatusJSON() -> StationStatusEnvelope? {
    // Use the currently running executable path if possible; otherwise rely on PATH.
    // We deliberately avoid writing reports (no I/O churn).
    let cmd = "wub station status --format json --no-write-report"
    let output = runShell(cmd)
    guard !output.isEmpty else { return nil }
    if let data = output.data(using: .utf8) {
      return try? JSONDecoder().decode(StationStatusEnvelope.self, from: data)
    }
    return nil
  }

  private static func runShell(_ cmd: String) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-lc", cmd]
    let out = Pipe()
    let err = Pipe()
    p.standardOutput = out
    p.standardError = err
    do {
      try p.run()
    } catch {
      return ""
    }
    p.waitUntilExit()
    let od = out.fileHandleForReading.readDataToEndOfFile()
    let ed = err.fileHandleForReading.readDataToEndOfFile()
    let s = (String(data: od, encoding: .utf8) ?? "") + (String(data: ed, encoding: .utf8) ?? "")
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
