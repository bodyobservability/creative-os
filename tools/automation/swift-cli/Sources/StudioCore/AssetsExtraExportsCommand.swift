import Foundation
import ArgumentParser
import Yams

extension Assets {
  struct ExportExtras: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-extras",
      abstract: "Export return FX racks and master safety chain presets into canonical repo paths."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Spec YAML describing extra exports.")
    var spec: String = WubDefaults.profileSpecPath("assets/export/extra_exports.v1.yaml")

    @Option(name: .long, help: "Anchors pack passed to apply.")
    var anchorsPack: String?

    @Option(name: .long) var minBytes: Int = 20000
    @Option(name: .long) var warnBytes: Int = 80000
    @Flag(name: .long) var overwrite: Bool = false
    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    func run() async throws {
      try StationGate.enforceOrThrow(force: force, anchorsPackHint: anchorsPack, commandName: "assets export-extras")

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

      let specText = try String(contentsOfFile: spec, encoding: .utf8)
      let doc = try (Yams.load(yaml: specText) as? [String: Any]) ?? [:]
      let exports = doc["exports"] as? [[String: Any]] ?? []

      let exe = CommandLine.arguments.first ?? "wub"
      var items: [ExtraExportItemV1] = []
      var reasons: [String] = []
      var warn = false

      for ex in exports {
        let id = ex["id"] as? String ?? "unknown"
        let track = ex["track_name"] as? String
        let devToken = ex["device_name_contains"] as? String ?? "BASS"
        let outPath = ex["output_path"] as? String ?? ""

        if outPath.isEmpty {
          items.append(.init(id: id, outputPath: outPath, bytes: nil, result: "failed", notes: "missing_output_path"))
          reasons.append("missing output_path for \(id)")
          continue
        }

        let outURL = URL(fileURLWithPath: outPath)
        try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: outPath) && !overwrite {
          items.append(.init(id: id, outputPath: outPath, bytes: fileSize(outPath), result: "skipped", notes: "exists_use_overwrite"))
          continue
        }
        if FileManager.default.fileExists(atPath: outPath) && overwrite {
          try? FileManager.default.removeItem(atPath: outPath)
        }

        let plan = AssetsPlanBuilder.buildRackExportPlan(trackName: track, rackName: devToken, outDir: outURL.deletingLastPathComponent().path, fileName: outURL.lastPathComponent)
        let planPath = plansDir.appendingPathComponent("export_\(id).plan.v1.json")
        let planData = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
        try planData.write(to: planPath)

        var args = ["apply","--plan", planPath.path]
        if let ap = anchorsPack { args += ["--anchors-pack", ap] }
        let code = try await runProcess(exe: exe, args: args)
        if code != 0 {
          items.append(.init(id: id, outputPath: outPath, bytes: nil, result: "failed", notes: "apply_exit=\(code)"))
          reasons.append("apply failed for \(id) exit=\(code)")
          continue
        }

        if !FileManager.default.fileExists(atPath: outPath) {
          items.append(.init(id: id, outputPath: outPath, bytes: nil, result: "failed", notes: "missing_file"))
          reasons.append("missing file: \(outPath)")
          continue
        }

        let sz = fileSize(outPath) ?? 0
        if sz < minBytes {
          items.append(.init(id: id, outputPath: outPath, bytes: sz, result: "failed", notes: "too_small"))
          reasons.append("too_small(\(sz)<\(minBytes)) for \(outPath)")
          continue
        }
        var note: String? = nil
        if sz < warnBytes {
          warn = true
          note = "below_warn_bytes"
          reasons.append("warn below_warn_bytes(\(sz)<\(warnBytes)) for \(outPath)")
        }
        items.append(.init(id: id, outputPath: outPath, bytes: sz, result: "exported", notes: note))
      }

      let status: String = reasons.contains(where: { $0.contains("apply failed") || $0.contains("missing file") || $0.contains("too_small") }) ? "fail" : (warn ? "warn" : "pass")
      let receipt = ExtraExportsReceiptV1(schemaVersion: 1,
                                          runId: runId,
                                          timestamp: ISO8601DateFormatter().string(from: Date()),
                                          job: "extra_exports",
                                          status: status,
                                          items: items,
                                          reasons: reasons)
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("extra_exports_receipt.v1.json"))
      print("\nreceipt: runs/\(runId)/extra_exports_receipt.v1.json")
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

    private func fileSize(_ path: String) -> Int? {
      (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
    }
  }
}
