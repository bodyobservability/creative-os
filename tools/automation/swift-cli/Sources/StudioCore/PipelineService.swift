import Foundation

struct PipelineService {
  struct CutProfileConfig {
    let profileDev: String
    let rackId: String
    let profileId: String
    let macro: String
    let positions: String
    let exportDir: String
    let midiDest: String
    let cc: Int
    let channel: Int
    let baselineMode: String
    let baseline: String?
    let releaseOut: String?
    let thresholds: String
    let runsDir: String
  }

  static func cutProfile(config: CutProfileConfig) async throws -> ReleaseCutReceiptV1 {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
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

    let tunedOut = runDir.appendingPathComponent("tuned_profile.yaml").path
    let calArgs = [
      "sonic", "calibrate",
      "--macro", config.macro,
      "--positions", config.positions,
      "--export-dir", config.exportDir,
      "--midi-dest", config.midiDest,
      "--cc", String(config.cc),
      "--channel", String(config.channel),
      "--profile", config.profileDev,
      "--out-profile", tunedOut,
      "--rack-id", config.rackId,
      "--profile-id", config.profileId,
      "--thresholds", config.thresholds
    ]
    _ = await step("sonic_calibrate", calArgs)
    let sweepPath = runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
    artifacts["current_sweep"] = sweepPath
    artifacts["tuned_profile"] = tunedOut

    let basePath = config.baseline ?? WubDefaults.profileSpecPath("sonic/baselines/\(config.rackId)/\(config.macro).baseline.v1.json")
    artifacts["baseline"] = basePath

    if config.baselineMode == "set-if-missing" {
      if !FileManager.default.fileExists(atPath: basePath) {
        _ = await step("baseline_set", ["sonic", "baseline", "set", "--rack-id", config.rackId, "--profile-id", config.profileId, "--macro", config.macro, "--sweep", sweepPath])
      }
    } else if config.baselineMode == "update" {
      _ = await step("baseline_set", ["sonic", "baseline", "set", "--rack-id", config.rackId, "--profile-id", config.profileId, "--macro", config.macro, "--sweep", sweepPath])
    }

    var promoteArgs = [
      "release", "promote-profile",
      "--profile", tunedOut,
      "--rack-id", config.rackId,
      "--macro", config.macro,
      "--baseline", basePath,
      "--current-sweep", sweepPath
    ]
    if let out = config.releaseOut { promoteArgs += ["--out", out] }
    _ = await step("release_promote", promoteArgs)

    let status = reasons.isEmpty ? "pass" : "fail"
    artifacts["run_dir"] = "\(config.runsDir)/\(runId)"
    let receipt = ReleaseCutReceiptV1(
      schemaVersion: 1,
      runId: runId,
      timestamp: ISO8601DateFormatter().string(from: Date()),
      status: status,
      inputs: [
        "profile_dev": config.profileDev,
        "rack_id": config.rackId,
        "profile_id": config.profileId,
        "macro": config.macro,
        "baseline_mode": config.baselineMode,
        "positions": config.positions
      ],
      steps: steps,
      artifacts: artifacts,
      reasons: reasons
    )
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("release_cut_receipt.v1.json"))
    return receipt
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
