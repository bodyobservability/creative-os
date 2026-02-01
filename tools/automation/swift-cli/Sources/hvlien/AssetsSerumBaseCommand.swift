import Foundation
import ArgumentParser

extension Assets {
  struct ExportSerumBase: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-serum-base",
      abstract: "Export Serum base patch to library/serum/ via Ableton/Serum UI automation."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Target output path.")
    var out: String = "library/serum/HVLIEN_SERUM_BASE_v1.0.fxp"

    @Option(name: .long, help: "Anchors pack path passed to apply.")
    var anchorsPack: String?

    @Option(name: .long, help: "Minimum bytes for exported file.")
    var minBytes: Int = 5000

    @Option(name: .long, help: "Warn if bytes below this.")
    var warnBytes: Int = 20000

    @Flag(name: .long, help: "Overwrite existing file if present.")
    var overwrite: Bool = false

    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    func run() async throws {
      try StationGate.enforceOrThrow(force: force, anchorsPackHint: anchorsPack, commandName: "assets export-serum-base")

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

      if FileManager.default.fileExists(atPath: out) && !overwrite {
        print("File exists (use --overwrite to replace): \(out)")
        throw ExitCode(2)
      }
      if FileManager.default.fileExists(atPath: out) && overwrite {
        try? FileManager.default.removeItem(atPath: out)
      }

      // Copy the included plan into run dir so it's immutable per run.
      let planSrc = "specs/assets/plans/serum_base_export.plan.v1.json"
      let planDst = plansDir.appendingPathComponent("serum_base_export.plan.v1.json")
      let data = try Data(contentsOf: URL(fileURLWithPath: planSrc))
      try data.write(to: planDst)

      let exe = CommandLine.arguments.first ?? "hvlien"
      var args = ["apply","--plan", planDst.path]
      if let ap = anchorsPack { args += ["--anchors-pack", ap] }
      let code = try await runProcess(exe: exe, args: args)
      if code != 0 {
        let receipt = SerumBaseExportReceiptV1(schemaVersion: 1, runId: runId, timestamp: ISO8601DateFormatter().string(from: Date()),
          job: "serum_base_export", status: "fail", targetPath: out, bytes: nil, reasons: ["apply_exit=\(code)"])
        try JSONIO.save(receipt, to: runDir.appendingPathComponent("serum_base_export_receipt.v1.json"))
        throw ExitCode(code)
      }

      var reasons: [String] = []
      if !FileManager.default.fileExists(atPath: out) { reasons.append("missing_file") }

      let sz = (try? FileManager.default.attributesOfItem(atPath: out)[.size] as? Int) ?? nil
      var status = "pass"
      if let s = sz, s < minBytes { status = "fail"; reasons.append("too_small(\(s)<\(minBytes))") }
      else if let s = sz, s < warnBytes { status = "warn"; reasons.append("below_warn_bytes(\(s)<\(warnBytes))") }
      if !reasons.isEmpty && status == "pass" { status = "warn" }

      let receipt = SerumBaseExportReceiptV1(schemaVersion: 1, runId: runId, timestamp: ISO8601DateFormatter().string(from: Date()),
        job: "serum_base_export", status: status, targetPath: out, bytes: sz, reasons: reasons)
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("serum_base_export_receipt.v1.json"))

      print("receipt: runs/\(runId)/serum_base_export_receipt.v1.json")
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
