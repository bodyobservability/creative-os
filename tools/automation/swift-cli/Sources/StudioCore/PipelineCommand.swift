import Foundation
import ArgumentParser

struct Pipeline: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "pipeline",
    abstract: "Release pipeline orchestration (v8.6).",
    subcommands: [CutProfile.self]
  )

  struct CutProfile: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "cut-profile",
      abstract: "One-command release cut: calibrate -> (optional baseline set) -> promote-profile."
    )

    @Option(name: .long, help: "Dev/tuned profile YAML (candidate).")
    var profileDev: String

    @Option(name: .long, help: "Rack id.")
    var rackId: String

    @Option(name: .long, help: "Profile id (e.g. bass_lead_v1).")
    var profileId: String

    @Option(name: .long, help: "Macro to calibrate (e.g. Width).")
    var macro: String = "Width"

    @Option(name: .long, help: "Macro positions for sweep (e.g. 0,0.25,0.5,0.75,1).")
    var positions: String = "0,0.25,0.5,0.75,1"

    @Option(name: .long, help: "Export dir used by sweep-compile.")
    var exportDir: String

    @Option(name: .long, help: "MIDI dest contains (IAC recommended).")
    var midiDest: String = "IAC"

    @Option(name: .long, help: "CC mapped to macro in Ableton.")
    var cc: Int

    @Option(name: .long, help: "MIDI channel (1-16).")
    var channel: Int = 1

    @Option(name: .long, help: "Baseline mode: use|set-if-missing|update")
    var baselineMode: String = "set-if-missing"

    @Option(name: .long, help: "Baseline path (canonical). If omitted, uses profiles/<active_profile>/specs/sonic/baselines/<rack>/<macro>.baseline.v1.json")
    var baseline: String?

    @Option(name: .long, help: "Release output path override (optional).")
    var releaseOut: String?

    @Option(name: .long, help: "Thresholds JSON for sweep (optional).")
    var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/bass_music_sweep_defaults.v1.json")

    func run() async throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

      let exe = CommandLine.arguments.first ?? "wub"
      var steps: [PipelineStepV1] = []
      var reasons: [String] = []
      var artifacts: [String: String] = [:]

      func step(_ id: String, _ args: [String]) async -> Int32 {
        let cmd = ([exe] + args).joined(separator: " ")
        let code: Int32
        do { code = try await runProcess(exe: exe, args: args) }
        catch { steps.append(.init(id: id, command: cmd, exitCode: 999)); reasons.append("\(id): error"); return 999 }
        steps.append(.init(id: id, command: cmd, exitCode: Int(code)))
        if code != 0 { reasons.append("\(id): exit=\(code)") }
        return code
      }

      // 1) Calibrate -> produces tuned_profile.yaml and sweep receipt in the run folder (v7.6)
      let tunedOut = runDir.appendingPathComponent("tuned_profile.yaml").path
      let calArgs = [
        "sonic","calibrate",
        "--macro", macro,
        "--positions", positions,
        "--export-dir", exportDir,
        "--midi-dest", midiDest,
        "--cc", String(cc),
        "--channel", String(channel),
        "--profile", profileDev,
        "--out-profile", tunedOut,
        "--rack-id", rackId,
        "--profile-id", profileId,
        "--thresholds", thresholds
      ]
      _ = await step("sonic_calibrate", calArgs)
      let sweepPath = runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
      artifacts["current_sweep"] = sweepPath
      artifacts["tuned_profile"] = tunedOut

      // 2) Baseline set/update if requested (v8.5 baseline set)
      let basePath = baseline ?? WubDefaults.profileSpecPath("sonic/baselines/\(rackId)/\(macro).baseline.v1.json")
      artifacts["baseline"] = basePath

      if baselineMode == "set-if-missing" {
        if !FileManager.default.fileExists(atPath: basePath) {
          _ = await step("baseline_set", ["sonic","baseline","set","--rack-id", rackId, "--profile-id", profileId, "--macro", macro, "--sweep", sweepPath])
        }
      } else if baselineMode == "update" {
        _ = await step("baseline_set", ["sonic","baseline","set","--rack-id", rackId, "--profile-id", profileId, "--macro", macro, "--sweep", sweepPath])
      }

      // 3) Promote profile (v8.2) -> runs certify + rack verify gates
      var promoteArgs = [
        "release","promote-profile",
        "--profile", tunedOut,
        "--rack-id", rackId,
        "--macro", macro,
        "--baseline", basePath,
        "--current-sweep", sweepPath
      ]
      if let out = releaseOut { promoteArgs += ["--out", out] }
      _ = await step("release_promote", promoteArgs)

      let status = reasons.isEmpty ? "pass" : "fail"
      artifacts["run_dir"] = "runs/\(runId)"
      let receipt = ReleaseCutReceiptV1(
        schemaVersion: 1,
        runId: runId,
        timestamp: ISO8601DateFormatter().string(from: Date()),
        status: status,
        inputs: [
          "profile_dev": profileDev,
          "rack_id": rackId,
          "profile_id": profileId,
          "macro": macro,
          "baseline_mode": baselineMode,
          "positions": positions
        ],
        steps: steps,
        artifacts: artifacts,
        reasons: reasons
      )
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("release_cut_receipt.v1.json"))
      print("receipt: runs/\(runId)/release_cut_receipt.v1.json")
      if status != "pass" { throw ExitCode(1) }
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
