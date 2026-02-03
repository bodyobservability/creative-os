import Foundation
import ArgumentParser
import Yams

struct StationService {
  struct Config {
    let profile: String
    let profilePath: String?
    let anchorsPack: String?
    let fix: Bool
  }

  static func certify(config: Config) async throws -> CreativeOS.ServiceResult {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let exe = CommandLine.arguments.first ?? "wub"
    let profPath = config.profilePath ?? WubDefaults.profileSpecPath("station/profiles/\(config.profile).yaml")
    let pText = try String(contentsOfFile: profPath, encoding: .utf8)
    let cfg = try loadProfile(yaml: pText)

    var steps: [StationStepV1] = []
    var reasons: [String] = []

    func runStep(_ id: String, _ args: [String]) async -> Int32 {
      let cmd = ([exe] + args).joined(separator: " ")
      let code: Int32
      do { code = try await runProcess(exe: exe, args: args) }
      catch { steps.append(.init(id: id, command: cmd, exitCode: 999)); reasons.append("\(id): error"); return 999 }
      steps.append(.init(id: id, command: cmd, exitCode: Int(code)))
      if code != 0 { reasons.append("\(id): exit=\(code)") }
      return code
    }

    var sessionArgs = ["session","compile","--profile", cfg.sessionProfileId, "--profile-path", cfg.sessionProfilePath]
    if let ap = (config.anchorsPack ?? cfg.sessionAnchorsPack) { sessionArgs += ["--anchors-pack", ap] }
    if config.fix { sessionArgs += ["--fix"] }
    let sCode = await runStep("session_compile", sessionArgs)

    var currentSweepPath = cfg.baselineCurrentSweepPath
    if cfg.autoSweepEnabled {
      let sweepOut = runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
      currentSweepPath = sweepOut

      var scArgs = ["sonic","sweep-compile",
                    "--macro", cfg.macro,
                    "--positions", cfg.autoPositions,
                    "--export-dir", cfg.autoExportDir,
                    "--base-name", cfg.autoBaseName,
                    "--midi-dest", cfg.autoMidiDest,
                    "--cc", String(cfg.autoCc),
                    "--channel", String(cfg.autoChannel),
                    "--export-chord", cfg.autoExportChord,
                    "--wait-seconds", String(cfg.autoWaitSeconds)]
      if let th = cfg.autoThresholds { scArgs += ["--thresholds", th] }
      scArgs += ["--rack-id", cfg.rackId, "--profile-id", cfg.profileId]
      _ = await runStep("sonic_sweep_compile", scArgs)

      var sweepArgs = ["sonic","sweep","--macro", cfg.macro, "--dir", cfg.autoExportDir, "--out", sweepOut]
      if let th = cfg.autoThresholds { sweepArgs += ["--thresholds", th] }
      sweepArgs += ["--rack-id", cfg.rackId, "--profile-id", cfg.profileId]
      _ = await runStep("sonic_sweep", sweepArgs)
    }

    let cCode = await runStep("sonic_certify",
      ["sonic","certify",
       "--baseline", cfg.baseline,
       "--sweep", currentSweepPath,
       "--rack-id", cfg.rackId,
       "--profile-id", cfg.profileId,
       "--macro", cfg.macro])

    let status = (sCode == 0 && cCode == 0 && reasons.isEmpty) ? "pass" : "fail"

    let artifacts: [String: String] = [
      "station_profile": profPath,
      "session_profile": cfg.sessionProfilePath,
      "baseline": cfg.baseline,
      "current_sweep": currentSweepPath,
      "run_dir": "runs/\(runId)"
    ]

    let receipt = StationReceiptV1(schemaVersion: 1,
                                   runId: runId,
                                   timestamp: ISO8601DateFormatter().string(from: Date()),
                                   stationProfile: profPath,
                                   status: status,
                                   artifacts: artifacts,
                                   steps: steps,
                                   reasons: reasons)
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("station_receipt.v1.json"))

    let planSteps = steps.map { step in
      CreativeOS.PlanStep(id: step.id,
                          agent: "station",
                          type: .manualRequired,
                          description: "Run: \(step.command)",
                          effects: [CreativeOS.Effect(id: step.id, kind: .process, target: step.command, description: "Station certify step")],
                          idempotent: true,
                          manualReason: "station_certify")
    }

    return CreativeOS.ServiceResult(observed: CreativeOS.ObservedStateSlice(agentId: "station", data: nil, raw: nil),
                                    checks: [],
                                    steps: planSteps)
  }

  private struct ProfileCfg {
    let sessionProfileId: String
    let sessionProfilePath: String
    let sessionAnchorsPack: String?

    let macro: String
    let baseline: String
    let rackId: String
    let profileId: String
    let baselineCurrentSweepPath: String

    let autoSweepEnabled: Bool
    let autoPositions: String
    let autoExportDir: String
    let autoBaseName: String
    let autoMidiDest: String
    let autoCc: Int
    let autoChannel: Int
    let autoExportChord: String
    let autoWaitSeconds: Double
    let autoThresholds: String?
  }

  private static func loadProfile(yaml: String) throws -> ProfileCfg {
    let loaded = try Yams.load(yaml: yaml)
    guard let root = loaded as? [String: Any] else { throw ValidationError("Invalid station profile YAML") }

    func get(_ path: [String]) -> Any? {
      var cur: Any? = root
      for k in path {
        if let m = cur as? [String: Any] { cur = m[k] } else { return nil }
      }
      return cur
    }

    let sessionPath = (get(["session","profile"]) as? String) ?? WubDefaults.profileSpecPath("station/profiles/bass_v1.yaml")
    let sessionProfileId = URL(fileURLWithPath: sessionPath).deletingPathExtension().lastPathComponent
    let sessionAnchorsPack = get(["session","anchors_pack"]) as? String

    let macro = (get(["sonic","macro"]) as? String) ?? "Width"
    let baseline = (get(["sonic","baseline"]) as? String) ?? ""
    let rackId = (get(["sonic","rack_id"]) as? String) ?? ""
    let profileId = (get(["sonic","profile_id"]) as? String) ?? ""

    let currentSweep = (get(["sonic","current_sweep"]) as? String) ?? ""

    let auto = get(["sonic","auto_sweep"]) as? [String: Any]
    let enabled = (auto?["enabled"] as? Bool) ?? true
    let positions = (auto?["positions"] as? String) ?? "0,0.25,0.5,0.75,1"
    let exportDir = (auto?["export_dir"] as? String) ?? "/tmp/wub_exports"
    let baseName = (auto?["base_name"] as? String) ?? "BassLead"
    let midiDest = (auto?["midi_dest"] as? String) ?? "IAC"
    let cc = (auto?["cc"] as? Int) ?? 21
    let channel = (auto?["channel"] as? Int) ?? 1
    let chord = (auto?["export_chord"] as? String) ?? "CMD+SHIFT+R"
    let wait = (auto?["wait_seconds"] as? Double) ?? 8.0
    let th = auto?["thresholds"] as? String

    return ProfileCfg(sessionProfileId: sessionProfileId,
                      sessionProfilePath: sessionPath,
                      sessionAnchorsPack: sessionAnchorsPack,
                      macro: macro,
                      baseline: baseline,
                      rackId: rackId,
                      profileId: profileId,
                      baselineCurrentSweepPath: currentSweep,
                      autoSweepEnabled: enabled,
                      autoPositions: positions,
                      autoExportDir: exportDir,
                      autoBaseName: baseName,
                      autoMidiDest: midiDest,
                      autoCc: cc,
                      autoChannel: channel,
                      autoExportChord: chord,
                      autoWaitSeconds: wait,
                      autoThresholds: th)
  }

  private static func runProcess(exe: String, args: [String]) async throws -> Int32 {
    return try await withCheckedThrowingContinuation { cont in
      let p = Process()
      p.executableURL = URL(fileURLWithPath: exe)
      p.arguments = args
      p.standardOutput = FileHandle.standardOutput
      p.standardError = FileHandle.standardError
      p.terminationHandler = { proc in cont.resume(returning: proc.terminationStatus) }
      do { try p.run() } catch { cont.resume(throwing: error) }
    }
  }
}
