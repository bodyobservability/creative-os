import Foundation
import ArgumentParser
import Yams

extension Assets {
  struct ExportFinishingBays: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-finishing-bays",
      abstract: "Export finishing bay Ableton sets (.als) into repo paths (batch Save As)."
    )

    @OptionGroup var common: CommonOptions

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long, help: "Finishing bays export spec YAML.")
    var spec: String = "specs/assets/export/finishing_bays_export.v1.yaml"

    @Option(name: .long, help: "Anchors pack passed to apply.")
    var anchorsPack: String?

    @Option(name: .long, help: "Minimum bytes for exported .als.")
    var minBytes: Int = 200000

    @Option(name: .long, help: "Warn if bytes below this.")
    var warnBytes: Int = 1000000

    @Flag(name: .long, help: "Overwrite existing files.")
    var overwrite: Bool = false

    @Flag(name: .long, help: "Prompt before exporting each bay (recommended).")
    var promptEach: Bool = true

    @Flag(name: .long, inversion: .prefixedNo, help: "Run export preflight before executing.")
    var preflight: Bool = true

    func run() async throws {
      try StationGate.enforceOrThrow(force: force, anchorsPackHint: anchorsPack, commandName: "assets export-finishing-bays")

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
      let bays = doc["bays"] as? [[String: Any]] ?? []

      let exe = CommandLine.arguments.first ?? "hvlien"
      var items: [FinishingBayExportItemV1] = []
      var reasons: [String] = []
      var warn = false

      for b in bays {
        let bayId = b["id"] as? String ?? "unknown"
        let name = b["name"] as? String ?? bayId
        let outPath = b["output_path"] as? String ?? ""

        if outPath.isEmpty {
          items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: nil, result: "failed", notes: "missing_output_path"))
          reasons.append("missing output_path for \(bayId)")
          continue
        }

        if promptEach {
          print("\nOpen the correct Ableton bay set for: \(name)")
          print("Target export: \(outPath)")
          print("Press Enter to export this bay (or type 's' to skip, 'q' to abort): ", terminator: "")
          let resp = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
          if resp == "q" { reasons.append("aborted_by_user"); break }
          if resp == "s" {
            items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: fileSize(outPath), result: "skipped", notes: "user_skipped"))
            continue
          }
        }

        let outURL = URL(fileURLWithPath: outPath)
        let targetDir = outURL.deletingLastPathComponent().path
        let fileName = outURL.lastPathComponent
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: targetDir, isDirectory: true), withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: outPath) && !overwrite {
          items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: fileSize(outPath), result: "skipped", notes: "exists_use_overwrite"))
          continue
        }
        if FileManager.default.fileExists(atPath: outPath) && overwrite {
          try? FileManager.default.removeItem(atPath: outPath)
        }

        // plan
        let plan = FinishingBaysPlanBuilder.buildSaveAsPlan(targetDir: targetDir, fileName: fileName)
        let planPath = plansDir.appendingPathComponent("export_bay_\(bayId).plan.v1.json")
        let planData = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
        try planData.write(to: planPath)

        var args = ["apply","--plan", planPath.path]
        if let ap = anchorsPack { args += ["--anchors-pack", ap] }
        let code = try await runProcess(exe: exe, args: args)
        if code != 0 {
          items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: nil, result: "failed", notes: "apply_exit=\(code)"))
          reasons.append("apply failed for \(bayId) exit=\(code)")
          continue
        }

        if !FileManager.default.fileExists(atPath: outPath) {
          items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: nil, result: "failed", notes: "missing_file"))
          reasons.append("missing file: \(outPath)")
          continue
        }

        let sz = fileSize(outPath) ?? 0
        if sz < minBytes {
          items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: sz, result: "failed", notes: "too_small"))
          reasons.append("too_small(\(sz)<\(minBytes)) for \(outPath)")
          continue
        }
        var note: String? = nil
        if sz < warnBytes {
          warn = true
          note = "below_warn_bytes"
          reasons.append("warn below_warn_bytes(\(sz)<\(warnBytes)) for \(outPath)")
        }
        items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: sz, result: "exported", notes: note))
      }

      let status: String = reasons.contains(where: { $0.contains("apply failed") || $0.contains("missing file") || $0.contains("too_small") }) ? "fail" : (warn ? "warn" : "pass")
      let receipt = FinishingBaysExportReceiptV1(schemaVersion: 1,
                                                 runId: runId,
                                                 timestamp: ISO8601DateFormatter().string(from: Date()),
                                                 job: "finishing_bays_export",
                                                 status: status,
                                                 items: items,
                                                 reasons: reasons)
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("finishing_bays_export_receipt.v1.json"))
      print("\nreceipt: runs/\(runId)/finishing_bays_export_receipt.v1.json")
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
