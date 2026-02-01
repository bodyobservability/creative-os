import Foundation
import ArgumentParser

struct Repair: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "repair",
    abstract: "Run the standard repair recipe: export-all → index build → drift check → drift fix (if needed)."
  )

  @Option(name: .long, help: "Anchors pack hint for exports and drift.")
  var anchorsPackHint: String = "specs/automation/anchors/<pack_id>"

  @Flag(name: .long, help: "Skip confirmation prompt.")
  var yes: Bool = false

  @Flag(name: .long, help: "Overwrite artifacts during export-all.")
  var overwrite: Bool = true

  func run() async throws {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let hv = CommandLine.arguments.first ?? "hvlien"
    let exportArgs = [hv, "assets", "export-all", "--anchors-pack", anchorsPackHint] + (overwrite ? ["--overwrite"] : [])
    let indexArgs = [hv, "index", "build"]
    let driftCheckArgs = [hv, "drift", "check", "--anchors-pack-hint", anchorsPackHint]
    let driftFixArgs = [hv, "drift", "fix", "--anchors-pack-hint", anchorsPackHint]

    let plan = [
      exportArgs.joined(separator: " "),
      indexArgs.joined(separator: " "),
      driftCheckArgs.joined(separator: " "),
      driftFixArgs.joined(separator: " ")
    ]

    print("REPAIR PLAN (v1)")
    for p in plan { print("- " + p) }

    if !yes {
      print("\nProceed with repair recipe? [y/N] ", terminator: "")
      let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
      if ans != "y" && ans != "yes" { return }
    }

    var steps: [RepairStepV1] = []
    var reasons: [String] = []
    var status: String = "pass"

    @discardableResult
    func step(_ id: String, _ args: [String]) async -> Int32 {
      let cmd = args.joined(separator: " ")
      let code: Int32
      do { code = try await runProcess(exe: args[0], args: Array(args.dropFirst())) }
      catch {
        steps.append(.init(id: id, command: cmd, exitCode: 999))
        reasons.append("\(id): error")
        status = "fail"
        return 999
      }
      steps.append(.init(id: id, command: cmd, exitCode: Int(code)))
      if code != 0 {
        reasons.append("\(id): exit=\(code)")
        if status == "pass" { status = "fail" }
      }
      return code
    }

    let exportCode = await step("export_all", exportArgs)
    if exportCode != 0 { finalize(runId: runId, runDir: runDir, steps: steps, reasons: reasons, status: status); throw ExitCode(1) }

    let indexCode = await step("index_build", indexArgs)
    if indexCode != 0 { finalize(runId: runId, runDir: runDir, steps: steps, reasons: reasons, status: status); throw ExitCode(1) }

    let driftCode = await step("drift_check", driftCheckArgs)
    if driftCode != 0 {
      let fixCode = await step("drift_fix", driftFixArgs)
      if fixCode == 0 && status == "fail" { status = "warn" }
    }

    finalize(runId: runId, runDir: runDir, steps: steps, reasons: reasons, status: status)
    if status == "fail" { throw ExitCode(1) }
  }

  private func finalize(runId: String, runDir: URL, steps: [RepairStepV1], reasons: [String], status: String) {
    let receipt = RepairReceiptV1(schemaVersion: 1,
                                  runId: runId,
                                  timestamp: ISO8601DateFormatter().string(from: Date()),
                                  status: status,
                                  steps: steps,
                                  reasons: reasons)
    try? JSONIO.save(receipt, to: runDir.appendingPathComponent("repair_receipt.v1.json"))
    print("receipt: runs/\(runId)/repair_receipt.v1.json")
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
