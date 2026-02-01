import Foundation
import ArgumentParser

extension Assets {
  struct ExportPerformanceSet: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-performance-set",
      abstract: "Export the currently open Ableton performance set (.als) into the repo path using Save As automation."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Target output path (repo-relative or absolute).")
    var out: String = WubDefaults.packPath("ableton/performance-sets/BASS_PERFORMANCE_SET_v1.0.als")

    @Option(name: .long, help: "Anchors pack path passed to apply.")
    var anchorsPack: String?

    @Option(name: .long, help: "Minimum bytes for exported .als.")
    var minBytes: Int = 200000

    @Option(name: .long, help: "Warn if bytes below this.")
    var warnBytes: Int = 1000000

    @Flag(name: .long, help: "Do not run apply; only generate plan.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Overwrite existing file if present.")
    var overwrite: Bool = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    func run() async throws {
      try StationGate.enforceOrThrow(force: force, anchorsPackHint: anchorsPack, commandName: "assets export-performance-set")

      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
      let plansDir = runDir.appendingPathComponent("plans", isDirectory: true)
      try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

      if preflight {
        let report = try await ExportPreflightRunner.run(common: common,
                                                         anchorsPack: anchorsPack,
                                                         runId: runId,
                                                         runDir: runDir)
        if report.status == "fail" { throw ExitCode(2) }
      }

      let outURL = URL(fileURLWithPath: out)
      let targetDir = outURL.deletingLastPathComponent().path
      let fileName = outURL.lastPathComponent

      try FileManager.default.createDirectory(at: URL(fileURLWithPath: targetDir, isDirectory: true), withIntermediateDirectories: true)

      if FileManager.default.fileExists(atPath: out) && !overwrite {
        print("File exists (use --overwrite to replace): \(out)")
        throw ExitCode(2)
      }
      if FileManager.default.fileExists(atPath: out) && overwrite {
        try? FileManager.default.removeItem(atPath: out)
      }

      let plan = PerformanceSetPlanBuilder.buildPerformanceSetExportPlan(targetDir: targetDir, fileName: fileName)
      let planPath = plansDir.appendingPathComponent("export_performance_set.plan.v1.json")
      let planData = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
      try planData.write(to: planPath)

      if dryRun {
        print("DRY RUN plan: \(planPath.path)")
        print("target: \(out)")
        return
      }

      let exe = CommandLine.arguments.first ?? "wub"
      var args = ["apply","--plan", planPath.path]
      if let ap = anchorsPack { args += ["--anchors-pack", ap] }
      let code = try await runProcess(exe: exe, args: args)
      if code != 0 {
        let receipt = PerformanceSetExportReceiptV1(schemaVersion: 1, runId: runId, timestamp: ISO8601DateFormatter().string(from: Date()),
          job: "performance_set_export", status: "fail", targetPath: out, bytes: nil, reasons: ["apply_exit=\(code)"])
        try JSONIO.save(receipt, to: runDir.appendingPathComponent("performance_set_export_receipt.v1.json"))
        throw ExitCode(code)
      }

      var reasons: [String] = []
      if !FileManager.default.fileExists(atPath: out) {
        reasons.append("missing_file")
      }

      let sz = (try? FileManager.default.attributesOfItem(atPath: out)[.size] as? Int) ?? nil
      var status = "pass"
      if let s = sz, s < minBytes { status = "fail"; reasons.append("too_small(\(s)<\(minBytes))") }
      else if let s = sz, s < warnBytes { status = "warn"; reasons.append("below_warn_bytes(\(s)<\(warnBytes))") }

      if !reasons.isEmpty && status == "pass" { status = "warn" }

      let receipt = PerformanceSetExportReceiptV1(schemaVersion: 1, runId: runId, timestamp: ISO8601DateFormatter().string(from: Date()),
        job: "performance_set_export", status: status, targetPath: out, bytes: sz, reasons: reasons)
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("performance_set_export_receipt.v1.json"))

      print("receipt: runs/\(runId)/performance_set_export_receipt.v1.json")
      if status == "fail" { throw ExitCode(1) }
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
