import Foundation
import ArgumentParser

struct Assets: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "assets",
    abstract: "Asset export pipeline (v9.5).",
    subcommands: [
      ExportRacks.self,
      ExportPerformanceSet.self,
      ExportFinishingBays.self,
      ExportSerumBase.self,
      ExportExtras.self,
      ExportAll.self
    ]
  )

  struct ExportRacks: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-racks",
      abstract: "Export Ableton rack presets (.adg) into a canonical repo folder using v4 apply automation."
    )

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Rack pack manifest JSON.")
    var manifest: String = "specs/library/racks/rack_pack_manifest.v1.json"

    @Option(name: .long, help: "Output directory for exported racks.")
    var outDir: String = "ableton/racks/BASS_RACKS_v1.0"

    @Option(name: .long, help: "Anchors pack path passed to apply.")
    var anchorsPack: String?

    @Option(name: .long, help: "Minimum bytes for exported rack file.")
    var minBytes: Int = 20000

    @Option(name: .long, help: "Warn if bytes below this.")
    var warnBytes: Int = 80000

    @Option(name: .long, help: "Overwrite policy: ask|always|never")
    var overwrite: String = "ask"

    @Flag(name: .long, help: "Do not run apply; only generate plans and print targets.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Interactive prompts (recommended).")
    var interactive: Bool = true

    func run() async throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
      let plansDir = runDir.appendingPathComponent("plans", isDirectory: true)
      try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

      let mfData = try Data(contentsOf: URL(fileURLWithPath: manifest))
      let mf = try JSONDecoder().decode(RackPackManifestV1.self, from: mfData)

      try FileManager.default.createDirectory(at: URL(fileURLWithPath: outDir, isDirectory: true), withIntermediateDirectories: true)

      var items: [RacksExportItemV1] = []
      var reasons: [String] = []
      var warn = false

      let exe = CommandLine.arguments.first ?? "hvlien"

      for rack in mf.racks {
        let targetTrack = rack.targetTrack ?? RackVerify.guessTrackHint(rack: rack)
        let fileName = sanitizeFileName(rack.displayName) + ".adg"
        let targetPath = URL(fileURLWithPath: outDir, isDirectory: true).appendingPathComponent(fileName).path

        // overwrite policy
        if FileManager.default.fileExists(atPath: targetPath) {
          if overwrite == "never" {
            items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: fileSize(targetPath), result: "skipped", notes: "exists"))
            continue
          }
          if overwrite == "ask" && interactive {
            print("\nFile exists: \(targetPath)")
            print("Overwrite? [y/N] ", terminator: "")
            let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if ans != "y" && ans != "yes" {
              items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: fileSize(targetPath), result: "skipped", notes: "user_skipped"))
              continue
            }
          }
          // remove existing before export so size check is deterministic
          try? FileManager.default.removeItem(atPath: targetPath)
        }

        // generate plan for this rack
        let plan = AssetsPlanBuilder.buildRackExportPlan(
          trackName: targetTrack,
          rackName: rack.displayName,
          outDir: outDir,
          fileName: fileName
        )
        let planPath = plansDir.appendingPathComponent("export_rack_\(RackVerify.sanitize(rack.rackId)).plan.v1.json")
        let planData = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
        try planData.write(to: planPath)

        if dryRun {
          print("DRY RUN: \(rack.rackId) -> \(targetPath) (plan: \(planPath.path))")
          items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: nil, result: "skipped", notes: "dry_run"))
          continue
        }

        // execute apply
        var args = ["apply","--plan", planPath.path]
        if let ap = anchorsPack { args += ["--anchors-pack", ap] }
        // keep strict actuator default in apply; allow fallback if common requires
        // allow-cgevent is controlled by user in their apply stack; we do not force it here.
        let code = try await runProcess(exe: exe, args: args)
        if code != 0 {
          items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: nil, result: "failed", notes: "apply_exit=\(code)"))
          reasons.append("apply failed for \(rack.rackId) exit=\(code)")
          continue
        }

        // verify file exists + size thresholds
        if !FileManager.default.fileExists(atPath: targetPath) {
          items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: nil, result: "failed", notes: "missing_file"))
          reasons.append("missing exported file: \(targetPath)")
          continue
        }

        let sz = fileSize(targetPath) ?? 0
        if sz < minBytes {
          items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: sz, result: "failed", notes: "too_small"))
          reasons.append("file below min_bytes (\(sz) < \(minBytes)): \(targetPath)")
          continue
        }
        var note: String? = nil
        if sz < warnBytes {
          warn = true
          note = "below_warn_bytes"
          reasons.append("warn: file below warn_bytes (\(sz) < \(warnBytes)): \(targetPath)")
        }
        items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: sz, result: "exported", notes: note))
      }

      let status: String = reasons.contains(where: { $0.contains("min_bytes") || $0.contains("apply failed") || $0.contains("missing exported") }) ? "fail" : (warn ? "warn" : "pass")
      let receipt = RacksExportReceiptV1(schemaVersion: 1,
                                         runId: runId,
                                         timestamp: ISO8601DateFormatter().string(from: Date()),
                                         job: "racks_export",
                                         status: status,
                                         outputDir: outDir,
                                         items: items,
                                         reasons: reasons)

      try JSONIO.save(receipt, to: runDir.appendingPathComponent("racks_export_receipt.v1.json"))
      print("\nreceipt: runs/\(runId)/racks_export_receipt.v1.json")
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

    private func sanitizeFileName(_ s: String) -> String {
      let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
      // replace path separators and illegal filename chars
      let cleaned = trimmed.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
      // collapse whitespace
      return cleaned.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
    }

    private func fileSize(_ path: String) -> Int? {
      (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
    }
  }
}
