import Foundation
import ArgumentParser

/// v7.3: semi-automated macro sweep runner.
/// - Prompts operator to set macro position (via controller or voice)
/// - Automates export prompt + file naming best-effort (expects Ableton export shortcut configured)
/// - Runs `wub sonic sweep` over the resulting folder
struct SonicSweepRun: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sweep-run",
    abstract: "Semi-automate macro sweeps: prompt to set macro position, export clip, then run sonic sweep."
  )

  @OptionGroup var common: CommonOptions

  @Option(name: .long, help: "Macro name (e.g. Width, Energy).")
  var macro: String

  @Option(name: .long, help: "Comma-separated positions (e.g. 0,0.25,0.5,0.75,1).")
  var positions: String

  @Option(name: .long, help: "Directory where exported audio files will land (must already be selected in Ableton save sheet).")
  var exportDir: String

  @Option(name: .long, help: "Base filename prefix for exports.")
  var baseName: String = "BASE"

  @Option(name: .long, help: "Rack id for attribution.")
  var rackId: String?

  @Option(name: .long, help: "Profile id for attribution.")
  var profileId: String?

  @Option(name: .long, help: "Export shortcut chord (default CMD+SHIFT+R). Remap if needed.")
  var exportChord: String = "CMD+SHIFT+R"

  @Option(name: .long, help: "Seconds to wait after triggering export (default 8). Increase for slower renders.")
  var waitSeconds: Double = 8.0

  @Option(name: .long, help: "Thresholds JSON for sweep evaluation.")
  var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/bass_music_sweep_defaults.v1.json")

  func run() async throws {
    let posList = parsePositions(positions)
    if posList.count < 2 { throw ValidationError("Need at least 2 positions.") }

    try FileManager.default.createDirectory(at: URL(fileURLWithPath: exportDir, isDirectory: true), withIntermediateDirectories: true)

    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()

    let exe = CommandLine.arguments.first ?? "wub"

    print("\n== v7.3 sweep-run ==")
    print("macro: \(macro)")
    print("positions: \(posList.map { String(format: "%.2f",$0) }.joined(separator: ", "))")
    print("export_dir: \(exportDir)\n")
    print("Assumptions: Ableton frontmost; export chord works; save sheet reachable; export dir already selected.\n")

    for p in posList {
      let posTag = String(format: "pos%.2f", p)
      let fname = "\(baseName)_\(macro)_\(posTag).wav"
      let fullOut = (exportDir as NSString).appendingPathComponent(fname)

      print("\n--- Position \(posTag) ---")
      print("1) Set macro '\(macro)' to \(String(format: "%.2f", p)) using controller/voice.")
      print("   When ready, press Enter. (Type 'q' then Enter to abort.)")
      let resp = readLine() ?? ""
      if resp.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "q" { throw ExitCode(3) }

      let planPath = ctx.runDir.appendingPathComponent("export_\(macro)_\(posTag).plan.v1.json")
      let plan = ExportPlanBuilder.buildExportPlan(exportChord: exportChord, filename: fname)
      let data = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: planPath)

      print("2) Trigger export + save as: \(fullOut)")
      _ = try await runProcess(exe: exe, args: ["apply","--plan", planPath.path, "--allow-cgevent"])

      print("3) Waiting \(waitSeconds)s for render...")
      try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000.0))
    }

    print("\n== Running sonic sweep ==")
    var args = ["sonic","sweep","--macro", macro, "--dir", exportDir]
    if !thresholds.isEmpty { args += ["--thresholds", thresholds] }
    if let rackId = rackId { args += ["--rack-id", rackId] }
    if let profileId = profileId { args += ["--profile-id", profileId] }

    let code = try await runProcess(exe: exe, args: args)
    if code != 0 { throw ExitCode(code) }
  }

  private func parsePositions(_ s: String) -> [Double] {
    s.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }.sorted()
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
