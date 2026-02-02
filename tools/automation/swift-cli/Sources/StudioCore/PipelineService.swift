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

    var steps: [PipelineStepV1] = []
    var reasons: [String] = []
    var artifacts: [String: String] = [:]

    func recordStep(_ id: String, _ command: String, _ exitCode: Int) {
      steps.append(.init(id: id, command: command, exitCode: exitCode))
      if exitCode != 0 { reasons.append("\(id): exit=\(exitCode)") }
    }

    let tunedOut = runDir.appendingPathComponent("tuned_profile.yaml").path
    let calExit: Int
    do {
      let receipt = try await SonicCalibrateService.run(config: .init(macro: config.macro,
                                                                      positions: config.positions,
                                                                      exportDir: config.exportDir,
                                                                      baseName: "BASE",
                                                                      midiDest: config.midiDest,
                                                                      cc: config.cc,
                                                                      channel: config.channel,
                                                                      exportChord: "CMD+SHIFT+R",
                                                                      waitSeconds: 8.0,
                                                                      thresholds: config.thresholds,
                                                                      profile: config.profileDev,
                                                                      outProfile: tunedOut,
                                                                      rackId: config.rackId,
                                                                      profileId: config.profileId,
                                                                      runsDir: config.runsDir))
      calExit = (receipt.status == "fail") ? 1 : 0
    } catch {
      reasons.append("sonic_calibrate: \(error.localizedDescription)")
      calExit = 999
    }
    recordStep("sonic_calibrate", "service: sonic.calibrate", calExit)
    let sweepPath = runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
    artifacts["current_sweep"] = sweepPath
    artifacts["tuned_profile"] = tunedOut

    let basePath = config.baseline ?? WubDefaults.profileSpecPath("sonic/baselines/\(config.rackId)/\(config.macro).baseline.v1.json")
    artifacts["baseline"] = basePath

    if config.baselineMode == "set-if-missing" {
      if !FileManager.default.fileExists(atPath: basePath) {
        let baseExit: Int
        do {
          _ = try BaselineService.set(config: .init(rackId: config.rackId,
                                                    profileId: config.profileId,
                                                    macro: config.macro,
                                                    sweep: sweepPath,
                                                    root: WubDefaults.profileSpecPath("sonic/baselines"),
                                                    index: WubDefaults.profileSpecPath("sonic/baselines/baseline_index.v1.json"),
                                                    notes: nil))
          baseExit = 0
        } catch {
          reasons.append("baseline_set: \(error.localizedDescription)")
          baseExit = 999
        }
        recordStep("baseline_set", "service: sonic.baseline_set", baseExit)
      }
    } else if config.baselineMode == "update" {
      let baseExit: Int
      do {
        _ = try BaselineService.set(config: .init(rackId: config.rackId,
                                                  profileId: config.profileId,
                                                  macro: config.macro,
                                                  sweep: sweepPath,
                                                  root: WubDefaults.profileSpecPath("sonic/baselines"),
                                                  index: WubDefaults.profileSpecPath("sonic/baselines/baseline_index.v1.json"),
                                                  notes: nil))
        baseExit = 0
      } catch {
        reasons.append("baseline_set: \(error.localizedDescription)")
        baseExit = 999
      }
      recordStep("baseline_set", "service: sonic.baseline_set", baseExit)
    }

    let promoteExit: Int
    do {
      let receipt = try await ReleaseService.promoteProfile(config: .init(profile: tunedOut,
                                                                          out: config.releaseOut,
                                                                          rackId: config.rackId,
                                                                          macro: config.macro,
                                                                          baseline: basePath,
                                                                          currentSweep: sweepPath,
                                                                          rackManifest: WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json"),
                                                                          runsDir: config.runsDir))
      promoteExit = (receipt.status == "fail") ? 1 : 0
    } catch {
      reasons.append("release_promote: \(error.localizedDescription)")
      promoteExit = 999
    }
    recordStep("release_promote", "service: release.promote_profile", promoteExit)

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

}
