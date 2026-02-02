import Foundation
import ArgumentParser
import Yams

struct AssetsExportRacksService {
  struct Config {
    let force: Bool
    let manifest: String
    let outDir: String
    let anchorsPack: String?
    let minBytes: Int
    let warnBytes: Int
    let overwrite: String
    let dryRun: Bool
    let interactive: Bool
    let preflight: Bool
    let runsDir: String
    let regionsConfig: String
  }

  static func run(config: Config) async throws -> RacksExportReceiptV1 {
    try StationGate.enforceOrThrow(force: config.force,
                                  anchorsPackHint: config.anchorsPack,
                                  commandName: "assets export-racks")

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let plansDir = runDir.appendingPathComponent("plans", isDirectory: true)
    try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

    if config.preflight {
      var common = CommonOptions()
      common.runsDir = config.runsDir
      common.regionsConfig = config.regionsConfig
      let report = try await ExportPreflightRunner.run(common: common,
                                                       anchorsPack: config.anchorsPack,
                                                       runId: runId,
                                                       runDir: runDir)
      if report.status == "fail" { throw ExitCode(2) }
    }

    let mfData = try Data(contentsOf: URL(fileURLWithPath: config.manifest))
    let mf = try JSONDecoder().decode(RackPackManifestV1.self, from: mfData)

    try FileManager.default.createDirectory(at: URL(fileURLWithPath: config.outDir, isDirectory: true), withIntermediateDirectories: true)

    var items: [RacksExportItemV1] = []
    var reasons: [String] = []
    var warn = false

    let exe = CommandLine.arguments.first ?? "wub"

    for rack in mf.racks {
      let targetTrack = rack.targetTrack ?? RackVerify.guessTrackHint(rack: rack)
      let fileName = sanitizeFileName(rack.displayName) + ".adg"
      let targetPath = URL(fileURLWithPath: config.outDir, isDirectory: true).appendingPathComponent(fileName).path

      if FileManager.default.fileExists(atPath: targetPath) {
        if config.overwrite == "never" {
          items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: fileSize(targetPath), result: "skipped", notes: "exists"))
          continue
        }
        if config.overwrite == "ask" && config.interactive {
          print("\nFile exists: \(targetPath)")
          print("Overwrite? [y/N] ", terminator: "")
          let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
          if ans != "y" && ans != "yes" {
            items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: fileSize(targetPath), result: "skipped", notes: "user_skipped"))
            continue
          }
        }
        try? FileManager.default.removeItem(atPath: targetPath)
      }

      let plan = AssetsPlanBuilder.buildRackExportPlan(trackName: targetTrack,
                                                       rackName: rack.displayName,
                                                       outDir: config.outDir,
                                                       fileName: fileName)
      let planPath = plansDir.appendingPathComponent("export_rack_\(RackVerify.sanitize(rack.rackId)).plan.v1.json")
      let planData = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
      try planData.write(to: planPath)

      if config.dryRun {
        print("DRY RUN: \(rack.rackId) -> \(targetPath) (plan: \(planPath.path))")
        items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: nil, result: "skipped", notes: "dry_run"))
        continue
      }

      var args = ["apply", "--plan", planPath.path]
      if let ap = config.anchorsPack { args += ["--anchors-pack", ap] }
      let code = try await runProcess(exe: exe, args: args)
      if code != 0 {
        items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: nil, result: "failed", notes: "apply_exit=\(code)"))
        reasons.append("apply failed for \(rack.rackId) exit=\(code)")
        continue
      }

      if !FileManager.default.fileExists(atPath: targetPath) {
        items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: nil, result: "failed", notes: "missing_file"))
        reasons.append("missing exported file: \(targetPath)")
        continue
      }

      let sz = fileSize(targetPath) ?? 0
      if sz < config.minBytes {
        items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: sz, result: "failed", notes: "too_small"))
        reasons.append("file below min_bytes (\(sz) < \(config.minBytes)): \(targetPath)")
        continue
      }
      var note: String? = nil
      if sz < config.warnBytes {
        warn = true
        note = "below_warn_bytes"
        reasons.append("warn: file below warn_bytes (\(sz) < \(config.warnBytes)): \(targetPath)")
      }
      items.append(.init(rackId: rack.rackId, displayName: rack.displayName, targetTrack: targetTrack, targetPath: targetPath, bytes: sz, result: "exported", notes: note))
    }

    let status: String = reasons.contains(where: { $0.contains("min_bytes") || $0.contains("apply failed") || $0.contains("missing exported") })
      ? "fail"
      : (warn ? "warn" : "pass")
    let receipt = RacksExportReceiptV1(schemaVersion: 1,
                                       runId: runId,
                                       timestamp: ISO8601DateFormatter().string(from: Date()),
                                       job: "racks_export",
                                       status: status,
                                       outputDir: config.outDir,
                                       items: items,
                                       reasons: reasons)

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("racks_export_receipt.v1.json"))
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

  private static func sanitizeFileName(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleaned = trimmed.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
    return cleaned.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
  }

  private static func fileSize(_ path: String) -> Int? {
    (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
  }
}

struct AssetsExportPerformanceSetService {
  struct Config {
    let force: Bool
    let out: String
    let anchorsPack: String?
    let minBytes: Int
    let warnBytes: Int
    let dryRun: Bool
    let overwrite: Bool
    let preflight: Bool
    let runsDir: String
    let regionsConfig: String
  }

  static func run(config: Config) async throws -> PerformanceSetExportReceiptV1 {
    try StationGate.enforceOrThrow(force: config.force,
                                  anchorsPackHint: config.anchorsPack,
                                  commandName: "assets export-performance-set")

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let plansDir = runDir.appendingPathComponent("plans", isDirectory: true)
    try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

    if config.preflight {
      var common = CommonOptions()
      common.runsDir = config.runsDir
      common.regionsConfig = config.regionsConfig
      let report = try await ExportPreflightRunner.run(common: common,
                                                       anchorsPack: config.anchorsPack,
                                                       runId: runId,
                                                       runDir: runDir)
      if report.status == "fail" { throw ExitCode(2) }
    }

    let outURL = URL(fileURLWithPath: config.out)
    let targetDir = outURL.deletingLastPathComponent().path
    let fileName = outURL.lastPathComponent

    try FileManager.default.createDirectory(at: URL(fileURLWithPath: targetDir, isDirectory: true), withIntermediateDirectories: true)

    if FileManager.default.fileExists(atPath: config.out) && !config.overwrite {
      print("File exists (use --overwrite to replace): \(config.out)")
      throw ExitCode(2)
    }
    if FileManager.default.fileExists(atPath: config.out) && config.overwrite {
      try? FileManager.default.removeItem(atPath: config.out)
    }

    let plan = PerformanceSetPlanBuilder.buildPerformanceSetExportPlan(targetDir: targetDir, fileName: fileName)
    let planPath = plansDir.appendingPathComponent("export_performance_set.plan.v1.json")
    let planData = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
    try planData.write(to: planPath)

    if config.dryRun {
      print("DRY RUN plan: \(planPath.path)")
      print("target: \(config.out)")
      return PerformanceSetExportReceiptV1(schemaVersion: 1,
                                           runId: runId,
                                           timestamp: ISO8601DateFormatter().string(from: Date()),
                                           job: "performance_set_export",
                                           status: "skip",
                                           targetPath: config.out,
                                           bytes: nil,
                                           reasons: ["dry_run"])
    }

    let exe = CommandLine.arguments.first ?? "wub"
    var args = ["apply", "--plan", planPath.path]
    if let ap = config.anchorsPack { args += ["--anchors-pack", ap] }
    let code = try await runProcess(exe: exe, args: args)
    if code != 0 {
      let receipt = PerformanceSetExportReceiptV1(schemaVersion: 1,
                                                  runId: runId,
                                                  timestamp: ISO8601DateFormatter().string(from: Date()),
                                                  job: "performance_set_export",
                                                  status: "fail",
                                                  targetPath: config.out,
                                                  bytes: nil,
                                                  reasons: ["apply_exit=\(code)"])
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("performance_set_export_receipt.v1.json"))
      throw ExitCode(code)
    }

    var reasons: [String] = []
    if !FileManager.default.fileExists(atPath: config.out) {
      reasons.append("missing_file")
    }

    let sz = (try? FileManager.default.attributesOfItem(atPath: config.out)[.size] as? Int) ?? nil
    var status = "pass"
    if let s = sz, s < config.minBytes { status = "fail"; reasons.append("too_small(\(s)<\(config.minBytes))") }
    else if let s = sz, s < config.warnBytes { status = "warn"; reasons.append("below_warn_bytes(\(s)<\(config.warnBytes))") }

    if !reasons.isEmpty && status == "pass" { status = "warn" }

    let receipt = PerformanceSetExportReceiptV1(schemaVersion: 1,
                                                runId: runId,
                                                timestamp: ISO8601DateFormatter().string(from: Date()),
                                                job: "performance_set_export",
                                                status: status,
                                                targetPath: config.out,
                                                bytes: sz,
                                                reasons: reasons)
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("performance_set_export_receipt.v1.json"))

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

struct AssetsExportFinishingBaysService {
  struct Config {
    let force: Bool
    let spec: String
    let anchorsPack: String?
    let minBytes: Int
    let warnBytes: Int
    let overwrite: Bool
    let promptEach: Bool
    let preflight: Bool
    let runsDir: String
    let regionsConfig: String
  }

  static func run(config: Config) async throws -> FinishingBaysExportReceiptV1 {
    try StationGate.enforceOrThrow(force: config.force,
                                  anchorsPackHint: config.anchorsPack,
                                  commandName: "assets export-finishing-bays")

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let plansDir = runDir.appendingPathComponent("plans", isDirectory: true)
    try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

    if config.preflight {
      var common = CommonOptions()
      common.runsDir = config.runsDir
      common.regionsConfig = config.regionsConfig
      let report = try await ExportPreflightRunner.run(common: common,
                                                       anchorsPack: config.anchorsPack,
                                                       runId: runId,
                                                       runDir: runDir)
      if report.status == "fail" { throw ExitCode(2) }
    }

    let specText = try String(contentsOfFile: config.spec, encoding: .utf8)
    let doc = try (Yams.load(yaml: specText) as? [String: Any]) ?? [:]
    let bays = doc["bays"] as? [[String: Any]] ?? []

    let exe = CommandLine.arguments.first ?? "wub"
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

      if config.promptEach {
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

      if FileManager.default.fileExists(atPath: outPath) && !config.overwrite {
        items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: fileSize(outPath), result: "skipped", notes: "exists_use_overwrite"))
        continue
      }
      if FileManager.default.fileExists(atPath: outPath) && config.overwrite {
        try? FileManager.default.removeItem(atPath: outPath)
      }

      let plan = FinishingBaysPlanBuilder.buildSaveAsPlan(targetDir: targetDir, fileName: fileName)
      let planPath = plansDir.appendingPathComponent("export_bay_\(bayId).plan.v1.json")
      let planData = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
      try planData.write(to: planPath)

      var args = ["apply", "--plan", planPath.path]
      if let ap = config.anchorsPack { args += ["--anchors-pack", ap] }
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
      if sz < config.minBytes {
        items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: sz, result: "failed", notes: "too_small"))
        reasons.append("too_small(\(sz)<\(config.minBytes)) for \(outPath)")
        continue
      }
      var note: String? = nil
      if sz < config.warnBytes {
        warn = true
        note = "below_warn_bytes"
        reasons.append("warn below_warn_bytes(\(sz)<\(config.warnBytes)) for \(outPath)")
      }
      items.append(.init(bayId: bayId, name: name, targetPath: outPath, bytes: sz, result: "exported", notes: note))
    }

    let status: String = reasons.contains(where: { $0.contains("apply failed") || $0.contains("missing file") || $0.contains("too_small") })
      ? "fail"
      : (warn ? "warn" : "pass")
    let receipt = FinishingBaysExportReceiptV1(schemaVersion: 1,
                                               runId: runId,
                                               timestamp: ISO8601DateFormatter().string(from: Date()),
                                               job: "finishing_bays_export",
                                               status: status,
                                               items: items,
                                               reasons: reasons)
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("finishing_bays_export_receipt.v1.json"))
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

  private static func fileSize(_ path: String) -> Int? {
    (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
  }
}

struct AssetsExportSerumBaseService {
  struct Config {
    let force: Bool
    let out: String
    let anchorsPack: String?
    let minBytes: Int
    let warnBytes: Int
    let overwrite: Bool
    let preflight: Bool
    let runsDir: String
    let regionsConfig: String
  }

  static func run(config: Config) async throws -> SerumBaseExportReceiptV1 {
    try StationGate.enforceOrThrow(force: config.force,
                                  anchorsPackHint: config.anchorsPack,
                                  commandName: "assets export-serum-base")

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let plansDir = runDir.appendingPathComponent("plans", isDirectory: true)
    try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

    if config.preflight {
      var common = CommonOptions()
      common.runsDir = config.runsDir
      common.regionsConfig = config.regionsConfig
      let report = try await ExportPreflightRunner.run(common: common,
                                                       anchorsPack: config.anchorsPack,
                                                       runId: runId,
                                                       runDir: runDir)
      if report.status == "fail" { throw ExitCode(2) }
    }

    if FileManager.default.fileExists(atPath: config.out) && !config.overwrite {
      print("File exists (use --overwrite to replace): \(config.out)")
      throw ExitCode(2)
    }
    if FileManager.default.fileExists(atPath: config.out) && config.overwrite {
      try? FileManager.default.removeItem(atPath: config.out)
    }

    let planSrc = WubDefaults.profileSpecPath("assets/plans/serum_base_export.plan.v1.json")
    let planDst = plansDir.appendingPathComponent("serum_base_export.plan.v1.json")
    let data = try Data(contentsOf: URL(fileURLWithPath: planSrc))
    try data.write(to: planDst)

    let exe = CommandLine.arguments.first ?? "wub"
    var args = ["apply", "--plan", planDst.path]
    if let ap = config.anchorsPack { args += ["--anchors-pack", ap] }
    let code = try await runProcess(exe: exe, args: args)
    if code != 0 {
      let receipt = SerumBaseExportReceiptV1(schemaVersion: 1,
                                             runId: runId,
                                             timestamp: ISO8601DateFormatter().string(from: Date()),
                                             job: "serum_base_export",
                                             status: "fail",
                                             targetPath: config.out,
                                             bytes: nil,
                                             reasons: ["apply_exit=\(code)"])
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("serum_base_export_receipt.v1.json"))
      throw ExitCode(code)
    }

    var reasons: [String] = []
    if !FileManager.default.fileExists(atPath: config.out) { reasons.append("missing_file") }

    let sz = (try? FileManager.default.attributesOfItem(atPath: config.out)[.size] as? Int) ?? nil
    var status = "pass"
    if let s = sz, s < config.minBytes { status = "fail"; reasons.append("too_small(\(s)<\(config.minBytes))") }
    else if let s = sz, s < config.warnBytes { status = "warn"; reasons.append("below_warn_bytes(\(s)<\(config.warnBytes))") }
    if !reasons.isEmpty && status == "pass" { status = "warn" }

    let receipt = SerumBaseExportReceiptV1(schemaVersion: 1,
                                           runId: runId,
                                           timestamp: ISO8601DateFormatter().string(from: Date()),
                                           job: "serum_base_export",
                                           status: status,
                                           targetPath: config.out,
                                           bytes: sz,
                                           reasons: reasons)
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("serum_base_export_receipt.v1.json"))

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

struct AssetsExportExtrasService {
  struct Config {
    let force: Bool
    let spec: String
    let anchorsPack: String?
    let minBytes: Int
    let warnBytes: Int
    let overwrite: Bool
    let preflight: Bool
    let runsDir: String
    let regionsConfig: String
  }

  static func run(config: Config) async throws -> ExtraExportsReceiptV1 {
    try StationGate.enforceOrThrow(force: config.force,
                                  anchorsPackHint: config.anchorsPack,
                                  commandName: "assets export-extras")

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let plansDir = runDir.appendingPathComponent("plans", isDirectory: true)
    try FileManager.default.createDirectory(at: plansDir, withIntermediateDirectories: true)

    if config.preflight {
      var common = CommonOptions()
      common.runsDir = config.runsDir
      common.regionsConfig = config.regionsConfig
      let report = try await ExportPreflightRunner.run(common: common,
                                                       anchorsPack: config.anchorsPack,
                                                       runId: runId,
                                                       runDir: runDir)
      if report.status == "fail" { throw ExitCode(2) }
    }

    let specText = try String(contentsOfFile: config.spec, encoding: .utf8)
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

      if FileManager.default.fileExists(atPath: outPath) && !config.overwrite {
        items.append(.init(id: id, outputPath: outPath, bytes: fileSize(outPath), result: "skipped", notes: "exists_use_overwrite"))
        continue
      }
      if FileManager.default.fileExists(atPath: outPath) && config.overwrite {
        try? FileManager.default.removeItem(atPath: outPath)
      }

      let plan = AssetsPlanBuilder.buildRackExportPlan(trackName: track,
                                                       rackName: devToken,
                                                       outDir: outURL.deletingLastPathComponent().path,
                                                       fileName: outURL.lastPathComponent)
      let planPath = plansDir.appendingPathComponent("export_\(id).plan.v1.json")
      let planData = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
      try planData.write(to: planPath)

      var args = ["apply", "--plan", planPath.path]
      if let ap = config.anchorsPack { args += ["--anchors-pack", ap] }
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
      if sz < config.minBytes {
        items.append(.init(id: id, outputPath: outPath, bytes: sz, result: "failed", notes: "too_small"))
        reasons.append("too_small(\(sz)<\(config.minBytes)) for \(outPath)")
        continue
      }
      var note: String? = nil
      if sz < config.warnBytes {
        warn = true
        note = "below_warn_bytes"
        reasons.append("warn below_warn_bytes(\(sz)<\(config.warnBytes)) for \(outPath)")
      }
      items.append(.init(id: id, outputPath: outPath, bytes: sz, result: "exported", notes: note))
    }

    let status: String = reasons.contains(where: { $0.contains("apply failed") || $0.contains("missing file") || $0.contains("too_small") })
      ? "fail"
      : (warn ? "warn" : "pass")
    let receipt = ExtraExportsReceiptV1(schemaVersion: 1,
                                        runId: runId,
                                        timestamp: ISO8601DateFormatter().string(from: Date()),
                                        job: "extra_exports",
                                        status: status,
                                        items: items,
                                        reasons: reasons)
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("extra_exports_receipt.v1.json"))
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

  private static func fileSize(_ path: String) -> Int? {
    (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int)
  }
}
