import Foundation
import ArgumentParser

struct SonicCertifyService {
  struct Config {
    let baseline: String
    let sweep: String
    let rackId: String
    let profileId: String
    let macro: String
    let runsDir: String
  }

  static func run(config: Config) async throws -> SonicCertifyCommand.SonicCertReceiptV1 {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let exe = CommandLine.arguments.first ?? "wub"
    let diffOut = runDir.appendingPathComponent("sonic_diff_receipt.v1.json").path

    let code = try await runProcess(exe: exe, args: [
      "sonic", "diff-sweep",
      "--baseline", config.baseline,
      "--current", config.sweep,
      "--out", diffOut
    ])

    let status = (code == 0) ? "pass" : "fail"
    let receipt = SonicCertifyCommand.SonicCertReceiptV1(schemaVersion: 1,
                                                        runId: runId,
                                                        timestamp: ISO8601DateFormatter().string(from: Date()),
                                                        rackId: config.rackId,
                                                        profileId: config.profileId,
                                                        macro: config.macro,
                                                        status: status,
                                                        artifacts: ["baseline": config.baseline, "current_sweep": config.sweep, "diff": diffOut],
                                                        reasons: (code == 0) ? [] : ["diff_failed"])

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("sonic_cert_receipt.v1.json"))
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

struct SonicCalibrateService {
  struct Config {
    let macro: String
    let positions: String
    let exportDir: String
    let baseName: String
    let midiDest: String
    let cc: Int
    let channel: Int
    let exportChord: String
    let waitSeconds: Double
    let thresholds: String
    let profile: String
    let outProfile: String?
    let rackId: String?
    let profileId: String?
    let runsDir: String
  }

  static func run(config: Config) async throws -> SonicCalibrateReceiptV1 {
    let posList = parsePositions(config.positions)
    if posList.count < 2 { throw ValidationError("Need at least 2 positions.") }

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
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

    var scArgs = ["sonic", "sweep-compile",
                  "--macro", config.macro,
                  "--positions", config.positions,
                  "--export-dir", config.exportDir,
                  "--base-name", config.baseName,
                  "--midi-dest", config.midiDest,
                  "--cc", String(config.cc),
                  "--channel", String(config.channel),
                  "--export-chord", config.exportChord,
                  "--wait-seconds", String(config.waitSeconds)]
    if !config.thresholds.isEmpty { scArgs += ["--thresholds", config.thresholds] }
    if let rackId = config.rackId { scArgs += ["--rack-id", rackId] }
    if let profileId = config.profileId { scArgs += ["--profile-id", profileId] }
    let scCode = await runStep("sweep_compile", scArgs)

    let sweepOut = runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
    var sweepArgs = ["sonic", "sweep", "--macro", config.macro, "--dir", config.exportDir, "--out", sweepOut]
    if !config.thresholds.isEmpty { sweepArgs += ["--thresholds", config.thresholds] }
    if let rackId = config.rackId { sweepArgs += ["--rack-id", rackId] }
    if let profileId = config.profileId { sweepArgs += ["--profile-id", profileId] }
    let sweepCode = await runStep("sonic_sweep", sweepArgs)

    let tunedOut = config.outProfile ?? runDir.appendingPathComponent("tuned_profile.yaml").path
    let tuneReceiptOut = runDir.appendingPathComponent("sonic_tune_receipt.v1.json").path
    let tuneArgs = ["sonic", "tune-profile",
                    "--sweep-receipt", sweepOut,
                    "--profile", config.profile,
                    "--out", tunedOut,
                    "--receipt-out", tuneReceiptOut]
    let tuneCode = await runStep("tune_profile", tuneArgs)

    let status = (scCode == 0 && sweepCode == 0 && tuneCode == 0) ? "pass" : "fail"

    let receipt = SonicCalibrateReceiptV1(
      schemaVersion: 1,
      runId: runId,
      timestamp: ISO8601DateFormatter().string(from: Date()),
      macro: config.macro,
      positions: posList,
      profileIn: config.profile,
      profileOut: tunedOut,
      rackId: config.rackId,
      profileId: config.profileId,
      status: status,
      artifacts: .init(exportDir: config.exportDir,
                       sweepReceipt: "\(config.runsDir)/\(runId)/sonic_sweep_receipt.v1.json",
                       tuneReceipt: "\(config.runsDir)/\(runId)/sonic_tune_receipt.v1.json",
                       runDir: "\(config.runsDir)/\(runId)"),
      steps: steps,
      reasons: reasons
    )

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("sonic_calibrate_receipt.v1.json"))
    return receipt
  }

  private static func parsePositions(_ s: String) -> [Double] {
    s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }.map { max(0.0, min(1.0, $0)) }.sorted()
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

struct SonicSweepRunService {
  struct Config {
    let macro: String
    let positions: String
    let exportDir: String
    let baseName: String
    let rackId: String?
    let profileId: String?
    let exportChord: String
    let waitSeconds: Double
    let thresholds: String
    let runsDir: String
  }

  static func run(config: Config) async throws {
    let posList = parsePositions(config.positions)
    if posList.count < 2 { throw ValidationError("Need at least 2 positions.") }

    try FileManager.default.createDirectory(at: URL(fileURLWithPath: config.exportDir, isDirectory: true), withIntermediateDirectories: true)

    var common = CommonOptions()
    common.runsDir = config.runsDir
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()

    let exe = CommandLine.arguments.first ?? "wub"

    print("\n== v7.3 sweep-run ==")
    print("macro: \(config.macro)")
    let positionsText = posList.map { String(format: "%.2f", $0) }.joined(separator: ", ")
    print("positions: \(positionsText)")
    print("export_dir: \(config.exportDir)\n")
    print("Assumptions: Ableton frontmost; export chord works; save sheet reachable; export dir already selected.\n")

    for p in posList {
      let posTag = String(format: "pos%.2f", p)
      let fname = "\(config.baseName)_\(config.macro)_\(posTag).wav"
      let fullOut = (config.exportDir as NSString).appendingPathComponent(fname)

      print("\n--- Position \(posTag) ---")
      let posLabel = String(format: "%.2f", p)
      print("1) Set macro '\(config.macro)' to \(posLabel) using controller/voice.")
      print("   When ready, press Enter. (Type 'q' then Enter to abort.)")
      let resp = readLine() ?? ""
      if resp.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "q" { throw ExitCode(3) }

      let planPath = ctx.runDir.appendingPathComponent("export_\(config.macro)_\(posTag).plan.v1.json")
      let plan = ExportPlanBuilder.buildExportPlan(exportChord: config.exportChord, filename: fname)
      let data = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: planPath)

      print("2) Trigger export + save as: \(fullOut)")
      _ = try await runProcess(exe: exe, args: ["apply", "--plan", planPath.path, "--allow-cgevent"])

      print("3) Waiting \(config.waitSeconds)s for render...")
      try await Task.sleep(nanoseconds: UInt64(config.waitSeconds * 1_000_000_000.0))
    }

    print("\n== Running sonic sweep ==")
    var args = ["sonic", "sweep", "--macro", config.macro, "--dir", config.exportDir]
    if !config.thresholds.isEmpty { args += ["--thresholds", config.thresholds] }
    if let rackId = config.rackId { args += ["--rack-id", rackId] }
    if let profileId = config.profileId { args += ["--profile-id", profileId] }

    let code = try await runProcess(exe: exe, args: args)
    if code != 0 { throw ExitCode(code) }
  }

  private static func parsePositions(_ s: String) -> [Double] {
    s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }.sorted()
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

struct SonicSweepCompileService {
  struct Config {
    let macro: String
    let positions: String
    let exportDir: String
    let baseName: String
    let midiDest: String
    let cc: Int
    let channel: Int
    let exportChord: String
    let waitSeconds: Double
    let thresholds: String
    let rackId: String?
    let profileId: String?
    let runsDir: String
  }

  static func run(config: Config) async throws -> SonicSweepCompileReceiptV1 {
    let posList = parsePositions(config.positions)
    if posList.count < 2 { throw ValidationError("Need at least 2 positions.") }

    try FileManager.default.createDirectory(at: URL(fileURLWithPath: config.exportDir, isDirectory: true), withIntermediateDirectories: true)

    var common = CommonOptions()
    common.runsDir = config.runsDir
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()
    let runDir = ctx.runDir

    let exe = CommandLine.arguments.first ?? "wub"

    var steps: [SonicSweepCompileStep] = []
    var reasons: [String] = []

    let sender = try MidiCCSender(portNameContains: config.midiDest)
    steps.append(.init(id: "midi_dest", detail: "Using MIDI dest contains='\(config.midiDest)' cc=\(config.cc) ch=\(config.channel)", exitCode: 0))

    for p in posList {
      let posTag = String(format: "pos%.2f", p)
      let fname = "\(config.baseName)_\(config.macro)_\(posTag).wav"
      let fullOut = (config.exportDir as NSString).appendingPathComponent(fname)

      let v = Int(round(p * 127.0))
      try sender.sendCC(cc: config.cc, value: v, channel: config.channel)
      steps.append(.init(id: "set_macro_\(posTag)", detail: "Sent CC\(config.cc)=\(v) ch=\(config.channel)", exitCode: 0))

      try? await Task.sleep(nanoseconds: 200_000_000)

      let planPath = runDir.appendingPathComponent("export_\(config.macro)_\(posTag).plan.v1.json")
      let plan = ExportPlanBuilder.buildExportPlan(exportChord: config.exportChord, filename: fname)
      let data = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: planPath)

      let code = try await runProcess(exe: exe, args: ["apply", "--plan", planPath.path, "--allow-cgevent"])
      steps.append(.init(id: "export_\(posTag)", detail: "Exported -> \(fullOut)", exitCode: Int(code)))
      if code != 0 { reasons.append("export \(posTag) failed exit=\(code)") }

      try await Task.sleep(nanoseconds: UInt64(config.waitSeconds * 1_000_000_000.0))
    }

    var sweepArgs = ["sonic", "sweep", "--macro", config.macro, "--dir", config.exportDir]
    if !config.thresholds.isEmpty { sweepArgs += ["--thresholds", config.thresholds] }
    if let rackId = config.rackId { sweepArgs += ["--rack-id", rackId] }
    if let profileId = config.profileId { sweepArgs += ["--profile-id", profileId] }

    let sweepCode = try await runProcess(exe: exe, args: sweepArgs)
    steps.append(.init(id: "sonic_sweep", detail: "sonic sweep dir=\(config.exportDir)", exitCode: Int(sweepCode)))
    if sweepCode != 0 { reasons.append("sonic sweep failed exit=\(sweepCode)") }

    let status = (reasons.isEmpty && sweepCode == 0) ? "pass" : "fail"
    let sweepReceiptPath = "\(config.runsDir)/\(RunContext.makeRunId())/sonic_sweep_receipt.v1.json"

    let receipt = SonicSweepCompileReceiptV1(
      schemaVersion: 1,
      runId: ctx.runId,
      timestamp: ISO8601DateFormatter().string(from: Date()),
      macro: config.macro,
      positions: posList,
      rackId: config.rackId,
      profileId: config.profileId,
      midi: SonicSweepCompileMidi(cc: config.cc, channel: config.channel, portNameContains: config.midiDest),
      status: status,
      artifacts: SonicSweepCompileArtifacts(exportDir: config.exportDir,
                                            sweepReceipt: sweepReceiptPath,
                                            runDir: "\(config.runsDir)/\(ctx.runId)"),
      steps: steps,
      reasons: reasons
    )

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("sonic_sweep_compile_receipt.v1.json"))
    return receipt
  }

  private static func parsePositions(_ s: String) -> [Double] {
    s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }.map { max(0.0, min(1.0, $0)) }.sorted()
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
