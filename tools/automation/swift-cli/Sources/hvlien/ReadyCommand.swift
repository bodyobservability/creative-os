import Foundation
import ArgumentParser

struct Ready: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ready",
    abstract: "Preflight verifier: are we ARTIFACT-READY? (v1.7.14)"
  )

  @Option(name: .long, help: "Anchors pack hint used only for suggested commands.")
  var anchorsPackHint: String = "specs/automation/anchors/<pack_id>"

  @Option(name: .long, help: "Artifact index path.")
  var artifactIndex: String = "checksums/index/artifact_index.v1.json"

  @Option(name: .long, help: "Run directory to inspect for drift/export receipts (optional). Defaults to latest runs/<id>.")
  var runDir: String? = nil

  @Flag(name: .long, help: "Write JSON report to runs/<run_id>/ready_report.v1.json")
  var writeReport: Bool = true

  func run() async throws {
    let runId = RunContext.makeRunId()
    let ts = ISO8601DateFormatter().string(from: Date())
    let chosenRunDir = runDir ?? latestRunDirPath()

    var checks: [ReadyCheckV1] = []
    var cmds: [String] = []
    var notes: [String] = []

    if !FileManager.default.fileExists(atPath: artifactIndex) {
      checks.append(.init(id: "artifact_index_present", status: "fail", details: ["path": artifactIndex]))
      cmds.append("hvlien index build")
    } else {
      checks.append(.init(id: "artifact_index_present", status: "pass", details: ["path": artifactIndex]))
      if let (missing, placeholder, stale) = artifactCounts(path: artifactIndex) {
        let pending = missing + placeholder
        let st = (pending == 0) ? "pass" : "fail"
        checks.append(.init(id: "artifact_pending_count", status: st, details: [
          "missing": String(missing),
          "placeholder": String(placeholder),
          "stale": String(stale)
        ]))
        if pending > 0 {
          cmds.append("hvlien assets export-all --anchors-pack \(anchorsPackHint) --overwrite")
          notes.append("Repo contains missing/placeholder artifacts.")
        } else if stale > 0 {
          checks.append(.init(id: "artifact_stale_budget", status: "warn", details: ["stale": String(stale)]))
          cmds.append("hvlien drift check --anchors-pack-hint \(anchorsPackHint)")
        }
      } else {
        checks.append(.init(id: "artifact_index_parse", status: "warn", details: ["reason":"could_not_parse_counts"]))
      }
    }

    let anchorsOk = FileManager.default.fileExists(atPath: anchorsPackHint)
    checks.append(.init(id: "anchors_pack_path_exists",
                        status: anchorsOk ? "pass" : "warn",
                        details: ["path": anchorsPackHint]))
    if !anchorsOk {
      cmds.append("hvlien validate-anchors --regions-config tools/automation/swift-cli/config/regions.v1.json --pack \(anchorsPackHint)")
      notes.append("Anchors pack path does not exist; update anchorsPackHint or capture/validate anchors.")
    }

    if let rd = chosenRunDir, let drift = findLatestJSON(withPrefix: "drift_report", inDir: rd) {
      if let st = readStatus(fromJSON: drift) {
        let mapped: String = (st == "pass") ? "pass" : (st == "fail" ? "fail" : "warn")
        checks.append(.init(id: "drift_status", status: mapped, details: ["status": st, "path": drift]))
        if st == "fail" {
          cmds.append("hvlien drift plan --anchors-pack-hint \(anchorsPackHint)")
          cmds.append("hvlien drift fix --anchors-pack-hint \(anchorsPackHint)")
        }
      } else {
        checks.append(.init(id: "drift_status", status: "skip", details: ["reason":"no_status_field"]))
      }
    } else {
      checks.append(.init(id: "drift_status", status: "skip", details: ["reason":"no_drift_report_found"]))
      cmds.append("hvlien drift check --anchors-pack-hint \(anchorsPackHint)")
    }

    let hasFail = checks.contains { $0.status == "fail" }
    let hasWarn = checks.contains { $0.status == "warn" }
    let status = hasFail ? "not_ready" : (hasWarn ? "warn" : "ready")

    var seen = Set<String>()
    let dedupCmds = cmds.filter { c in
      if seen.contains(c) { return false }
      seen.insert(c); return true
    }

    let report = ReadyReportV1(schemaVersion: 1,
                               runId: runId,
                               timestamp: ts,
                               status: status,
                               checks: checks,
                               recommendedCommands: dedupCmds,
                               notes: notes)

    print("READY CHECK (v1.7.14)")
    print("status: \(status.uppercased())")
    for c in checks {
      print("- \(c.id): \(c.status)")
    }
    if !dedupCmds.isEmpty {
      print("\nRecommended next commands:")
      for c in dedupCmds { print("  " + c) }
    }

    if writeReport {
      let outDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
      try JSONIO.save(report, to: outDir.appendingPathComponent("ready_report.v1.json"))
      print("\nreport: runs/\(runId)/ready_report.v1.json")
    }

    if status == "not_ready" { throw ExitCode(2) }
  }

  private func artifactCounts(path: String) -> (Int, Int, Int)? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let artifacts = obj["artifacts"] as? [[String: Any]] else { return nil }
    var missing = 0, placeholder = 0, stale = 0
    for a in artifacts {
      if let st = a["status"] as? [String: Any], let state = st["state"] as? String {
        if state == "missing" { missing += 1 }
        else if state == "placeholder" { placeholder += 1 }
        else if state == "stale" { stale += 1 }
      }
    }
    return (missing, placeholder, stale)
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

  private func findLatestJSON(withPrefix prefix: String, inDir dir: String) -> String? {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
    let candidates = files.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }.sorted()
    guard let chosen = candidates.last else { return nil }
    return URL(fileURLWithPath: dir).appendingPathComponent(chosen).path
  }

  private func readStatus(fromJSON path: String) -> String? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
    return obj["status"] as? String
  }
}
