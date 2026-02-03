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

    let diffOut = runDir.appendingPathComponent("sonic_diff_receipt.v1.json").path

    let diff = try SonicDiff.diff(baselinePath: config.baseline, currentPath: config.sweep)
    try JSONIO.save(diff, to: URL(fileURLWithPath: diffOut))

    let status = (diff.status == "fail") ? "fail" : "pass"
    let receipt = SonicCertifyCommand.SonicCertReceiptV1(schemaVersion: 1,
                                                        runId: runId,
                                                        timestamp: ISO8601DateFormatter().string(from: Date()),
                                                        rackId: config.rackId,
                                                        profileId: config.profileId,
                                                        macro: config.macro,
                                                        status: status,
                                                        artifacts: ["baseline": config.baseline, "current_sweep": config.sweep, "diff": diffOut],
                                                        reasons: (status == "pass") ? [] : ["diff_failed"])

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("sonic_cert_receipt.v1.json"))
    return receipt
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

    var steps: [SonicCalibrateStepV1] = []
    var reasons: [String] = []

    func recordStep(_ id: String, _ command: String, _ exitCode: Int) {
      steps.append(.init(id: id, command: command, exitCode: exitCode))
      if exitCode != 0 { reasons.append("\(id): exit=\(exitCode)") }
    }

    let scCode: Int
    do {
      let receipt = try await SonicSweepCompileService.run(config: .init(macro: config.macro,
                                                                         positions: config.positions,
                                                                         exportDir: config.exportDir,
                                                                         baseName: config.baseName,
                                                                         midiDest: config.midiDest,
                                                                         cc: config.cc,
                                                                         channel: config.channel,
                                                                         exportChord: config.exportChord,
                                                                         waitSeconds: config.waitSeconds,
                                                                         thresholds: config.thresholds,
                                                                         rackId: config.rackId,
                                                                         profileId: config.profileId,
                                                                         runsDir: config.runsDir))
      scCode = (receipt.status == "pass") ? 0 : 1
    } catch {
      reasons.append("sweep_compile: \(error.localizedDescription)")
      scCode = 999
    }
    recordStep("sweep_compile", "service: sonic.sweep_compile", scCode)

    let sweepOut = runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
    let sweepCode: Int
    do {
      let receipt = try runSonicSweep(macro: config.macro,
                                      dir: config.exportDir,
                                      thresholds: config.thresholds,
                                      rackId: config.rackId,
                                      profileId: config.profileId,
                                      runId: runId,
                                      runsDir: config.runsDir,
                                      outPath: sweepOut)
      sweepCode = (receipt.status == "fail") ? 1 : 0
    } catch {
      reasons.append("sonic_sweep: \(error.localizedDescription)")
      sweepCode = 999
    }
    recordStep("sonic_sweep", "service: sonic.sweep", sweepCode)

    let tunedOut = config.outProfile ?? runDir.appendingPathComponent("tuned_profile.yaml").path
    let tuneReceiptOut = runDir.appendingPathComponent("sonic_tune_receipt.v1.json").path
    let tuneCode: Int
    do {
      let (outProfile, receipt) = try SonicTune.tuneProfile(profileYamlPath: config.profile,
                                                            sweepReceiptPath: sweepOut,
                                                            outPath: tunedOut)
      try JSONIO.save(receipt, to: URL(fileURLWithPath: tuneReceiptOut))
      tuneCode = (receipt.status == "fail") ? 1 : 0
      if outProfile != tunedOut { _ = outProfile }
    } catch {
      reasons.append("tune_profile: \(error.localizedDescription)")
      tuneCode = 999
    }
    recordStep("tune_profile", "service: sonic.tune_profile", tuneCode)

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
      _ = try await ApplyService.run(config: .init(planPath: planPath.path,
                                                   anchorsPack: nil,
                                                   allowCgevent: true,
                                                   force: false,
                                                   runsDir: config.runsDir,
                                                   regionsConfig: RepoPaths.defaultRegionsConfigPath(),
                                                   evidence: "fail",
                                                   watchdogMs: 30000))

      print("3) Waiting \(config.waitSeconds)s for render...")
      try await Task.sleep(nanoseconds: UInt64(config.waitSeconds * 1_000_000_000.0))
    }

    print("\n== Running sonic sweep ==")
    let receipt = try runSonicSweep(macro: config.macro,
                                    dir: config.exportDir,
                                    thresholds: config.thresholds,
                                    rackId: config.rackId,
                                    profileId: config.profileId,
                                    runId: ctx.runId,
                                    runsDir: config.runsDir,
                                    outPath: nil)
    if receipt.status == "fail" { throw ExitCode(1) }
  }

  private static func parsePositions(_ s: String) -> [Double] {
    s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }.sorted()
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

      let result = try await ApplyService.run(config: .init(planPath: planPath.path,
                                                            anchorsPack: nil,
                                                            allowCgevent: true,
                                                            force: false,
                                                            runsDir: config.runsDir,
                                                            regionsConfig: RepoPaths.defaultRegionsConfigPath(),
                                                            evidence: "fail",
                                                            watchdogMs: 30000))
      let exitCode = (result.status == "success") ? 0 : 1
      steps.append(.init(id: "export_\(posTag)", detail: "Exported -> \(fullOut)", exitCode: exitCode))
      if exitCode != 0 { reasons.append("export \(posTag) failed status=\(result.status)") }

      try await Task.sleep(nanoseconds: UInt64(config.waitSeconds * 1_000_000_000.0))
    }

    let sweepReceipt = try runSonicSweep(macro: config.macro,
                                         dir: config.exportDir,
                                         thresholds: config.thresholds,
                                         rackId: config.rackId,
                                         profileId: config.profileId,
                                         runId: ctx.runId,
                                         runsDir: config.runsDir,
                                         outPath: nil)
    let sweepCode = (sweepReceipt.status == "fail") ? 1 : 0
    steps.append(.init(id: "sonic_sweep", detail: "sonic sweep dir=\(config.exportDir)", exitCode: sweepCode))
    if sweepCode != 0 { reasons.append("sonic sweep failed") }

    let status = (reasons.isEmpty && sweepCode == 0) ? "pass" : "fail"
    let sweepReceiptPath = "\(config.runsDir)/\(ctx.runId)/sonic_sweep_receipt.v1.json"

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

}

private func runSonicSweep(macro: String,
                           dir: String,
                           thresholds: String,
                           rackId: String?,
                           profileId: String?,
                           runId: String,
                           runsDir: String,
                           outPath: String?) throws -> SonicSweepReceiptV1 {
  let runDir = URL(fileURLWithPath: runsDir).appendingPathComponent(runId, isDirectory: true)
  try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

  let folder = URL(fileURLWithPath: dir, isDirectory: true)
  let files = (try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))
    .filter { ["wav","aiff","aif"].contains($0.pathExtension.lowercased()) }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }

  if files.count < 2 {
    throw ValidationError("Need at least 2 audio files in dir.")
  }

  let th = SonicSweep.loadThresholds(path: thresholds.isEmpty ? nil : thresholds)
  var samples: [SonicSweepSampleV1] = []

  for f in files {
    guard let pos = parsePosition(from: f.lastPathComponent) else { continue }
    let (metrics, _, _) = try SonicAnalyze.analyze(url: f)
    let (status, reasons) = SonicSweep.classifySample(metrics: metrics, thresholds: th)
    samples.append(SonicSweepSampleV1(position: pos, inputAudio: f.path, metrics: metrics, status: status, reasons: reasons))
  }

  if samples.count < 2 { throw ValidationError("Could not parse positions from filenames. Include like pos0.25.") }

  let positions = samples.map { $0.position }.sorted()
  let (status, summary, _) = SonicSweep.aggregate(macro: macro, samples: samples, thresholds: th)

  let thMap: [String: Double] = [
    "max_true_peak_dbfs": th.maxTruePeakDbfs,
    "max_dc_offset_abs": th.maxDcOffsetAbs,
    "min_stereo_correlation": th.minStereoCorrelation,
    "max_rms_dbfs_warn": th.maxRmsDbfsWarn,
    "max_rms_dbfs_fail": th.maxRmsDbfsFail
  ]

  let receipt = SonicSweepReceiptV1(
    schemaVersion: 1,
    runId: runId,
    timestamp: ISO8601DateFormatter().string(from: Date()),
    macro: macro,
    profileId: profileId,
    rackId: rackId,
    positions: positions,
    status: status,
    thresholds: thMap,
    summary: summary,
    samples: samples.sorted { $0.position < $1.position }
  )

  let out = outPath ?? runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
  try JSONIO.save(receipt, to: URL(fileURLWithPath: out))
  return receipt
}

private func parsePosition(from name: String) -> Double? {
  guard let r = name.range(of: "pos") else { return nil }
  let tail = name[r.upperBound...]
  let num = tail.prefix { (ch: Character) in
    ch.isNumber || ch == "." || ch == "-"
  }
  return Double(num)
}
