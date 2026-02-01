import Foundation
import ArgumentParser
import Yams

struct Station: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "station",
    abstract: "Station operations (v8.4).",
    subcommands: [Certify.self, Status.self]
  )

  struct Certify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "certify",
      abstract: "Turnkey station certify: session compile + (optional auto sweep) + sonic certify."
    )

    @Option(name: .long, help: "Station profile id (default: bass_v1).")
    var profile: String = "bass_v1"

    @Option(name: .long, help: "Station profile path override.")
    var profilePath: String?

    @Option(name: .long, help: "Anchors pack override (passed to session compile).")
    var anchorsPack: String?

    @Flag(name: .long, help: "Run doctor --fix during session/voice phase where applicable.")
    var fix: Bool = false

    func run() async throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

      let exe = CommandLine.arguments.first ?? "hvlien"
      let profPath = profilePath ?? "specs/station/profiles/\(profile).yaml"
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

      // 1) session compile
      var sessionArgs = ["session","compile","--profile", cfg.sessionProfileId, "--profile-path", cfg.sessionProfilePath]
      if let ap = (anchorsPack ?? cfg.sessionAnchorsPack) { sessionArgs += ["--anchors-pack", ap] }
      if fix { sessionArgs += ["--fix"] }
      let sCode = await runStep("session_compile", sessionArgs)

      // 2) optional auto sweep to produce current sweep receipt in this run dir
      var currentSweepPath = cfg.baselineCurrentSweepPath
      if cfg.autoSweepEnabled {
        let sweepOut = runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
        currentSweepPath = sweepOut

        // 2a) sweep-compile
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

        // 2b) sweep with explicit out path
        var sweepArgs = ["sonic","sweep","--macro", cfg.macro, "--dir", cfg.autoExportDir, "--out", sweepOut]
        if let th = cfg.autoThresholds { sweepArgs += ["--thresholds", th] }
        sweepArgs += ["--rack-id", cfg.rackId, "--profile-id", cfg.profileId]
        _ = await runStep("sonic_sweep", sweepArgs)
      }

      // 3) sonic certify
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

      print("receipt: runs/\(runId)/station_receipt.v1.json")
      if status != "pass" { throw ExitCode(1) }
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

    private func loadProfile(yaml: String) throws -> ProfileCfg {
      let loaded = try Yams.load(yaml: yaml)
      guard let root = loaded as? [String: Any] else { throw ValidationError("Invalid station profile YAML") }

      func get(_ path: [String]) -> Any? {
        var cur: Any? = root
        for k in path {
          if let m = cur as? [String: Any] { cur = m[k] } else { return nil }
        }
        return cur
      }

      let sessionPath = (get(["session","profile"]) as? String) ?? "specs/session/profiles/bass_v1.yaml"
      let sessionProfileId = URL(fileURLWithPath: sessionPath).deletingPathExtension().lastPathComponent
      let sessionAnchorsPack = get(["session","anchors_pack"]) as? String

      let macro = (get(["sonic","macro"]) as? String) ?? "Width"
      let baseline = (get(["sonic","baseline"]) as? String) ?? ""
      let rackId = (get(["sonic","rack_id"]) as? String) ?? ""
      let profileId = (get(["sonic","profile_id"]) as? String) ?? ""

      // legacy field if user wants to supply current sweep manually
      let currentSweep = (get(["sonic","current_sweep"]) as? String) ?? ""

      let auto = get(["sonic","auto_sweep"]) as? [String: Any]
      let enabled = (auto?["enabled"] as? Bool) ?? true
      let positions = (auto?["positions"] as? String) ?? "0,0.25,0.5,0.75,1"
      let exportDir = (auto?["export_dir"] as? String) ?? "/tmp/hvlien_exports"
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

    private func runProcess(exe: String, args: [String]) async throws -> Int32 {
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
}
