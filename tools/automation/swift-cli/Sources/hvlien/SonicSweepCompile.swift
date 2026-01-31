import Foundation
import ArgumentParser

/// v7.4: fully-automated macro setting via MIDI CC + export orchestration + sonic sweep.
/// Assumes Ableton mapping: Macro -> MIDI CC (set once).
struct SonicSweepCompile: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sweep-compile",
    abstract: "Automate macro sweep: set macro via MIDI CC, export per position, then run sonic sweep."
  )

  @OptionGroup var common: CommonOptions

  @Option(name: .long) var macro: String
  @Option(name: .long, help: "Comma-separated positions (0..1).") var positions: String
  @Option(name: .long) var exportDir: String
  @Option(name: .long) var baseName: String = "HVLIEN"
  @Option(name: .long, help: "MIDI destination name contains (e.g. 'IAC Driver' or 'Bus 1').") var midiDest: String = "IAC"
  @Option(name: .long, help: "CC number mapped to the macro (0-127).") var cc: Int
  @Option(name: .long, help: "MIDI channel 1-16 (default 1).") var channel: Int = 1
  @Option(name: .long, help: "Export chord (default CMD+SHIFT+R).") var exportChord: String = "CMD+SHIFT+R"
  @Option(name: .long, help: "Wait seconds after export (default 8).") var waitSeconds: Double = 8.0
  @Option(name: .long) var thresholds: String = "specs/sonic/thresholds/bass_music_sweep_defaults.v1.json"
  @Option(name: .long) var rackId: String?
  @Option(name: .long) var profileId: String?

  func run() async throws {
    let posList = parsePositions(positions)
    if posList.count < 2 { throw ValidationError("Need at least 2 positions.") }

    try FileManager.default.createDirectory(at: URL(fileURLWithPath: exportDir, isDirectory: true), withIntermediateDirectories: true)

    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()
    let runDir = ctx.runDir

    let exe = CommandLine.arguments.first ?? "hvlien"

    var steps: [SonicSweepCompileStep] = []
    var reasons: [String] = []

    // MIDI sender
    let sender = try MidiCCSender(portNameContains: midiDest)
    steps.append(.init(id: "midi_dest", detail: "Using MIDI dest contains='\(midiDest)' cc=\(cc) ch=\(channel)", exitCode: 0))

    for p in posList {
      let posTag = String(format: "pos%.2f", p)
      let fname = "\(baseName)_\(macro)_\(posTag).wav"
      let fullOut = (exportDir as NSString).appendingPathComponent(fname)

      // Set macro via CC
      let v = Int(round(p * 127.0))
      try sender.sendCC(cc: cc, value: v, channel: channel)
      steps.append(.init(id: "set_macro_\(posTag)", detail: "Sent CC\(cc)=\(v) ch=\(channel)", exitCode: 0))

      // Small settle
      try? await Task.sleep(nanoseconds: 200_000_000)

      // Export plan
      let planPath = runDir.appendingPathComponent("export_\(macro)_\(posTag).plan.v1.json")
      let plan = ExportPlanBuilder.buildExportPlan(exportChord: exportChord, filename: fname)
      let data = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: planPath)

      // Run apply to execute export flow
      let code = try await runProcess(exe: exe, args: ["apply","--plan", planPath.path, "--allow-cgevent"])
      steps.append(.init(id: "export_\(posTag)", detail: "Exported -> \(fullOut)", exitCode: Int(code)))
      if code != 0 { reasons.append("export \(posTag) failed exit=\(code)") }

      try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000.0))
    }

    // Run sonic sweep
    var sweepArgs = ["sonic","sweep","--macro", macro, "--dir", exportDir]
    if !thresholds.isEmpty { sweepArgs += ["--thresholds", thresholds] }
    if let rackId = rackId { sweepArgs += ["--rack-id", rackId] }
    if let profileId = profileId { sweepArgs += ["--profile-id", profileId] }

    let sweepCode = try await runProcess(exe: exe, args: sweepArgs)
    steps.append(.init(id: "sonic_sweep", detail: "sonic sweep dir=\(exportDir)", exitCode: Int(sweepCode)))
    if sweepCode != 0 { reasons.append("sonic sweep failed exit=\(sweepCode)") }

    let status = (reasons.isEmpty && sweepCode == 0) ? "pass" : "fail"
    let sweepReceiptPath = "runs/\(RunContext.makeRunId())/sonic_sweep_receipt.v1.json"

    let receipt = SonicSweepCompileReceiptV1(
      schemaVersion: 1,
      runId: ctx.runId,
      timestamp: ISO8601DateFormatter().string(from: Date()),
      macro: macro,
      positions: posList,
      rackId: rackId,
      profileId: profileId,
      midi: SonicSweepCompileMidi(cc: cc, channel: channel, portNameContains: midiDest),
      status: status,
      artifacts: SonicSweepCompileArtifacts(exportDir: exportDir, sweepReceipt: sweepReceiptPath, runDir: "runs/\(ctx.runId)"),
      steps: steps,
      reasons: reasons
    )

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("sonic_sweep_compile_receipt.v1.json"))
    print("receipt: runs/\(ctx.runId)/sonic_sweep_compile_receipt.v1.json")
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
