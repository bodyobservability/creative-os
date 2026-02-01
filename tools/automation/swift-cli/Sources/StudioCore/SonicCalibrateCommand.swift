import Foundation
import ArgumentParser

/// v7.6: one-command calibration loop
/// 1) sweep-compile (sets macro via MIDI CC + exports per position)
/// 2) sonic sweep (writes receipt to known path)
/// 3) sonic tune-profile (writes tuned profile + tune receipt)
struct SonicCalibrateCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "calibrate",
    abstract: "Calibrate a macro profile: sweep-compile -> sweep receipt -> tune profile."
  )

  @OptionGroup var common: CommonOptions

  @Option(name: .long) var macro: String
  @Option(name: .long) var positions: String
  @Option(name: .long) var exportDir: String
  @Option(name: .long) var baseName: String = "BASE"
  @Option(name: .long) var midiDest: String = "IAC"
  @Option(name: .long) var cc: Int
  @Option(name: .long) var channel: Int = 1
  @Option(name: .long) var exportChord: String = "CMD+SHIFT+R"
  @Option(name: .long) var waitSeconds: Double = 8.0
  @Option(name: .long) var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/bass_music_sweep_defaults.v1.json")

  @Option(name: .long, help: "Profile YAML to tune (v6.1).") var profile: String
  @Option(name: .long, help: "Output tuned profile path (optional).") var outProfile: String?
  @Option(name: .long) var rackId: String?
  @Option(name: .long) var profileId: String?

  func run() async throws {
    let posList = parsePositions(positions)
    if posList.count < 2 { throw ValidationError("Need at least 2 positions.") }

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let exe = CommandLine.arguments.first ?? "wub"
    var steps: [SonicCalibrateStepV1] = []
    var reasons: [String] = []

    func runStep(_ id: String, _ args: [String]) async -> Int32 {
      let cmd = ([exe] + args).joined(separator: " ")
      let code: Int32
      do { code = try await runProcess(exe: exe, args: args) }
      catch {
        steps.append(.init(id: id, command: cmd, exitCode: 999))
        reasons.append("\(id): \(error.localizedDescription)")
        return 999
      }
      steps.append(.init(id: id, command: cmd, exitCode: Int(code)))
      if code != 0 { reasons.append("\(id): exit=\(code)") }
      return code
    }

    // 1) sweep-compile (export audio files per position)
    var scArgs = ["sonic","sweep-compile",
                  "--macro", macro,
                  "--positions", positions,
                  "--export-dir", exportDir,
                  "--base-name", baseName,
                  "--midi-dest", midiDest,
                  "--cc", String(cc),
                  "--channel", String(channel),
                  "--export-chord", exportChord,
                  "--wait-seconds", String(waitSeconds)]
    if !thresholds.isEmpty { scArgs += ["--thresholds", thresholds] }
    if let rackId = rackId { scArgs += ["--rack-id", rackId] }
    if let profileId = profileId { scArgs += ["--profile-id", profileId] }
    let scCode = await runStep("sweep_compile", scArgs)

    // 2) sonic sweep with explicit out path (authoritative receipt)
    let sweepOut = runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
    var sweepArgs = ["sonic","sweep","--macro", macro, "--dir", exportDir, "--out", sweepOut]
    if !thresholds.isEmpty { sweepArgs += ["--thresholds", thresholds] }
    if let rackId = rackId { sweepArgs += ["--rack-id", rackId] }
    if let profileId = profileId { sweepArgs += ["--profile-id", profileId] }
    let sweepCode = await runStep("sonic_sweep", sweepArgs)

    // 3) tune-profile
    let tunedOut = outProfile ?? runDir.appendingPathComponent("tuned_profile.yaml").path
    let tuneReceiptOut = runDir.appendingPathComponent("sonic_tune_receipt.v1.json").path
    let tuneArgs = ["sonic","tune-profile",
                    "--sweep-receipt", sweepOut,
                    "--profile", profile,
                    "--out", tunedOut,
                    "--receipt-out", tuneReceiptOut]
    let tuneCode = await runStep("tune_profile", tuneArgs)

    let status = (scCode == 0 && sweepCode == 0 && tuneCode == 0) ? "pass" : "fail"

    let receipt = SonicCalibrateReceiptV1(
      schemaVersion: 1,
      runId: runId,
      timestamp: ISO8601DateFormatter().string(from: Date()),
      macro: macro,
      positions: posList,
      profileIn: profile,
      profileOut: tunedOut,
      rackId: rackId,
      profileId: profileId,
      status: status,
      artifacts: .init(exportDir: exportDir, sweepReceipt: "runs/\(runId)/sonic_sweep_receipt.v1.json", tuneReceipt: "runs/\(runId)/sonic_tune_receipt.v1.json", runDir: "runs/\(runId)"),
      steps: steps,
      reasons: reasons
    )

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("sonic_calibrate_receipt.v1.json"))
    print("receipt: runs/\(runId)/sonic_calibrate_receipt.v1.json")
    if status != "pass" { throw ExitCode(1) }
  }

  private func parsePositions(_ s: String) -> [Double] {
    s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }.map { max(0.0, min(1.0, $0)) }.sorted()
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
