import Foundation
import ArgumentParser
import AppKit

extension Station {
  struct Status: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "status",
      abstract: "Detect station state and emit station_state_report.v1.json (v1.7.16)."
    )

    @Option(name: .long, help: "Output format: human|json")
    var format: String = "human"

    @Option(name: .long, help: "Output path for JSON report (default runs/<run_id>/station_state_report.v1.json).")
    var out: String? = nil

    @Flag(name: .long, help: "Do not write report file; print only.")
    var noWriteReport: Bool = false

    @Option(name: .long, help: "Anchors pack hint (used only for evidence/reasons).")
    var anchorsPackHint: String = "specs/automation/anchors/<pack_id>"

    func run() async throws {
      let runId = RunContext.makeRunId()
      let ts = ISO8601DateFormatter().string(from: Date())

      let app = NSWorkspace.shared.frontmostApplication
      let bundleId = app?.bundleIdentifier ?? "unknown"
      let appName = app?.localizedName ?? "unknown"
      let frontmostAbleton = bundleId.contains("ableton") || appName.lowercased().contains("ableton")

      var signals: [StationStateSignalV1] = []
      var confidence = 0.2
      var votes: [String: Double] = ["idle":0,"editing":0,"exporting":0,"performing":0,"blocked":0,"unknown":0]
      var reasons: [String] = []

      // S1 frontmost app
      let weight = 0.35
      var stateVotes = votes
      if frontmostAbleton {
        stateVotes["editing", default: 0] += weight
        reasons.append("frontmost=ableton")
      } else {
        stateVotes["idle", default: 0] += weight
        reasons.append("frontmost!=ableton")
      }
      votes = stateVotes
      confidence += 0.25
      signals.append(StationStateSignalV1(
        id: "frontmost_app",
        value: "\(appName) (\(bundleId))",
        weight: weight,
        contribution: .init(stateVotes: stateVotes, confidenceDelta: 0.25)
      ))

      // S5 mode latch
      let modeLatch = loadModeLatch()
      if modeLatch == "performance" && frontmostAbleton {
        let w = 0.30
        var sv = votes
        sv["performing", default: 0] += w
        votes = sv
        confidence += 0.15
        reasons.append("mode_latch=performance")
        signals.append(StationStateSignalV1(
          id: "mode_latch",
          value: modeLatch,
          weight: w,
          contribution: .init(stateVotes: sv, confidenceDelta: 0.15)
        ))
      } else if modeLatch != nil {
        reasons.append("mode_latch=studio")
      }

      // Modal/save sheet hooks (integrate v1.7.17+)
      let modalDetected: Bool? = nil
      let saveSheetDetected: Bool? = nil

      let stationState = votes.max(by: { $0.value < $1.value })?.key ?? "unknown"
      var status = "pass"
      if stationState == "blocked" { status = "fail" }
      else if stationState == "performing" { status = "warn" }
      else if stationState == "unknown" { status = "warn" }
      confidence = min(1.0, max(0.0, confidence))

      let report = StationStateReportV1(
        schemaVersion: 1,
        runId: runId,
        timestamp: ts,
        status: status,
        confidence: confidence,
        stationState: stationState,
        activeApp: .init(bundleId: bundleId, name: appName),
        ableton: .init(detected: frontmostAbleton,
                       version: nil,
                       frontmost: frontmostAbleton,
                       setTitle: nil,
                       setPathHint: nil,
                       transport: .init(playing: nil, recording: nil),
                       ui: .init(modalDetected: modalDetected, saveSheetDetected: saveSheetDetected)),
        signals: signals,
        evidence: [
          "last_run_dir": latestRunDirPath(),
          "latest_ready_report": nil,
          "latest_drift_report": nil,
          "latest_export_receipt": nil,
          "latest_repair_receipt": nil,
          "screenshot_path": nil,
          "ocr_dump_path": nil
        ],
        reasons: reasons
      )

      if format == "human" {
        print("STATION STATUS (v1.7.16)")
        print("state: \(stationState.uppercased())   confidence: \(String(format: "%.2f", confidence))   status: \(status.uppercased())")
        print("frontmost: \(appName) (\(bundleId))  ableton_frontmost=\(frontmostAbleton ? "yes" : "no")")
        if let ml = modeLatch { print("mode_latch: \(ml)") }
        for r in reasons { print("- \(r)") }
      } else if format == "json" {
        let data = try JSONEncoder().encode(report)
        print(String(data: data, encoding: .utf8) ?? "")
      }

      if !noWriteReport {
        let outDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        let outPath = out ?? outDir.appendingPathComponent("station_state_report.v1.json").path
        try JSONIO.save(report, to: URL(fileURLWithPath: outPath))
        if format == "human" { print("report: \(outPath)") }
      }
    }

    private func loadModeLatch() -> String? {
      let p = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("notes/LOCAL_CONFIG.json").path
      guard FileManager.default.fileExists(atPath: p),
            let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
      return obj["mode"] as? String
    }

    private func latestRunDirPath() -> String? {
      let runs = URL(fileURLWithPath: "runs", isDirectory: true)
      guard FileManager.default.fileExists(atPath: runs.path) else { return nil }
      guard let items = try? FileManager.default.contentsOfDirectory(at: runs, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return nil }
      let dirs = items.filter { $0.hasDirectoryPath }
      let sorted = dirs.sorted { (a, b) -> Bool in
        let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
        let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
        return da > db
      }
      return sorted.first?.path
    }
  }
}
