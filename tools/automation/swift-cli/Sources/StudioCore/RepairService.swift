import Foundation
import ArgumentParser

struct RepairService {
  struct Config {
    let force: Bool
    let anchorsPackHint: String
    let yes: Bool
    let overwrite: Bool
    let runsDir: String
  }

  static func run(config: Config) async throws -> RepairReceiptV1? {
    try StationGate.enforceOrThrow(force: config.force,
                                  anchorsPackHint: config.anchorsPackHint,
                                  commandName: "repair")

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let hv = CommandLine.arguments.first ?? "wub"
    let exportArgs = [hv, "assets", "export-all", "--anchors-pack", config.anchorsPackHint] + (config.overwrite ? ["--overwrite"] : [])
    let indexArgs = [hv, "index", "build"]
    let driftCheckArgs = [hv, "drift", "check", "--anchors-pack-hint", config.anchorsPackHint]
    let driftFixArgs = [hv, "drift", "fix", "--anchors-pack-hint", config.anchorsPackHint]

    let plan = [
      exportArgs.joined(separator: " "),
      indexArgs.joined(separator: " "),
      driftCheckArgs.joined(separator: " "),
      driftFixArgs.joined(separator: " ")
    ]

    print("REPAIR PLAN (v1)")
    for p in plan { print("- " + p) }

    if !config.yes {
      print("\nProceed with repair recipe? [y/N] ", terminator: "")
      let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
      if ans != "y" && ans != "yes" { return nil }
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
    if exportCode != 0 {
      return finalize(runId: runId, runDir: runDir, steps: steps, reasons: reasons, status: status, runsDir: config.runsDir)
    }

    let indexCode = await step("index_build", indexArgs)
    if indexCode != 0 {
      return finalize(runId: runId, runDir: runDir, steps: steps, reasons: reasons, status: status, runsDir: config.runsDir)
    }

    let driftCode = await step("drift_check", driftCheckArgs)
    if driftCode != 0 {
      let fixCode = await step("drift_fix", driftFixArgs)
      if fixCode == 0 && status == "fail" { status = "warn" }
    }

    return finalize(runId: runId, runDir: runDir, steps: steps, reasons: reasons, status: status, runsDir: config.runsDir)
  }

  private static func finalize(runId: String,
                               runDir: URL,
                               steps: [RepairStepV1],
                               reasons: [String],
                               status: String,
                               runsDir: String) -> RepairReceiptV1 {
    let receipt = RepairReceiptV1(schemaVersion: 1,
                                  runId: runId,
                                  timestamp: ISO8601DateFormatter().string(from: Date()),
                                  status: status,
                                  steps: steps,
                                  reasons: reasons)
    try? JSONIO.save(receipt, to: runDir.appendingPathComponent("repair_receipt.v1.json"))
    print("receipt: \(runsDir)/\(runId)/repair_receipt.v1.json")
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
