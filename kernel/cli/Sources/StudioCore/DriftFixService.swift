import Foundation
import ArgumentParser

struct DriftFixService {
  struct Config {
    let force: Bool
    let artifactIndex: String
    let receiptIndex: String
    let anchorsPackHint: String
    let yes: Bool
    let dryRun: Bool
    let out: String?
    let runsDir: String
  }

  static func run(config: Config) async throws -> DriftFixReceiptV1 {
    try StationGate.enforceOrThrow(force: config.force,
                                  anchorsPackHint: config.anchorsPackHint,
                                  commandName: "drift fix")

    let aidx = try JSONIO.load(ArtifactIndexV1.self, from: URL(fileURLWithPath: config.artifactIndex))
    let ridx = try JSONIO.load(ReceiptIndexV1.self, from: URL(fileURLWithPath: config.receiptIndex))
    let budgets = DriftEvaluator.Budgets(staleWarnAfterS: 24*3600, staleFailAfterS: 7*24*3600, placeholderFail: true)
    let fixes = FixCatalog(anchorsPackHint: config.anchorsPackHint)

    let base = DriftEvaluator.evaluate(artifactIndex: aidx, receiptIndex: ridx, budgets: budgets, suggestedFixes: fixes)
    let findings: [DriftReportV2.Finding] = base.findings.map { f in
      DriftReportV2.Finding(id: f.id, severity: f.severity, kind: f.kind, artifactPath: f.artifactPath, title: f.title, why: f.why, fix: f.fix, details: f.details)
    }
    let recommended = DriftPlanner.recommendFixes(findings: findings)
    let commands = recommended.map { $0.command }.filter { !$0.isEmpty }

    let runId = RunContext.makeRunId()
    let ts = ISO8601DateFormatter().string(from: Date())
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    let outPath = config.out ?? runDir.appendingPathComponent("drift_fix_receipt.v1.json").path

    if commands.isEmpty {
      let receipt = DriftFixReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, status: "pass", plan: [], steps: [], reasons: ["no_fixes_needed"])
      try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))
      print("No fixes needed.")
      print("receipt: \(outPath)")
      return receipt
    }

    print("DRIFT FIX")
    print("Plan commands (\(commands.count)):\n")
    for c in commands { print("  " + c) }
    print("")

    if config.dryRun {
      let receipt = DriftFixReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, status: "pass", plan: commands, steps: [], reasons: ["dry_run"])
      try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))
      print("DRY RUN only. receipt: \(outPath)")
      return receipt
    }

    if !config.yes {
      print("Proceed to execute these commands? [y/N] ", terminator: "")
      let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
      if ans != "y" && ans != "yes" {
        let receipt = DriftFixReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, status: "aborted", plan: commands, steps: [], reasons: ["aborted_by_user"])
        try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))
        print("Aborted. receipt: \(outPath)")
        throw ExitCode(2)
      }
    }

    var steps: [DriftFixStepV1] = []
    var reasons: [String] = []
    var overallStatus = "pass"

    for (i, cmd) in commands.enumerated() {
      if !config.yes {
        print("\nRun now? [y/N]  \(cmd)\n> ", terminator: "")
        let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if ans != "y" && ans != "yes" {
          steps.append(.init(id: "step_\(i+1)", command: cmd, exitCode: 0, notes: "skipped_by_user"))
          overallStatus = (overallStatus == "fail") ? "fail" : "warn"
          continue
        }
      }

      let result = try await execute(command: cmd, config: config)
      steps.append(.init(id: "step_\(i+1)", command: cmd, exitCode: result.exitCode, notes: result.notes))
      if result.exitCode != 0 {
        reasons.append("command_failed(step_\(i+1))")
        overallStatus = "fail"
        break
      }
    }

    let receipt = DriftFixReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, status: overallStatus, plan: commands, steps: steps, reasons: reasons)
    try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))
    print("\nreceipt: \(outPath)")
    return receipt
  }

  private struct CommandExecutionResult {
    let exitCode: Int
    let notes: String?
  }

  private static func execute(command: String, config: Config) async throws -> CommandExecutionResult {
    let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.lowercased().hasPrefix("service:") else {
      return CommandExecutionResult(exitCode: 1, notes: "unsupported_command")
    }

    let parts = trimmed.split(separator: " ").map(String.init)
    guard let head = parts.first else {
      return CommandExecutionResult(exitCode: 1, notes: "empty_command")
    }
    let actionId = head.replacingOccurrences(of: "service:", with: "")
    let flags = parseFlags(Array(parts.dropFirst()))

    switch actionId {
    case "assets.export_racks":
      let receipt = try await AssetsExportRacksService.run(config: .init(force: config.force,
                                                                          manifest: flags["manifest"] ?? WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json"),
                                                                          outDir: flags["out_dir"] ?? WubDefaults.packPath("ableton/racks/BASS_RACKS"),
                                                                          anchorsPack: flags["anchors_pack"],
                                                                          minBytes: 20000,
                                                                          warnBytes: 80000,
                                                                          overwrite: flags["overwrite"] == "true" ? "always" : "ask",
                                                                          dryRun: false,
                                                                          interactive: false,
                                                                          preflight: true,
                                                                          runsDir: config.runsDir,
                                                                          regionsConfig: "kernel/cli/config/regions.v1.json"))
      return CommandExecutionResult(exitCode: receipt.status == "fail" ? 1 : 0, notes: nil)

    case "assets.export_performance_set":
      let receipt = try await AssetsExportPerformanceSetService.run(config: .init(force: config.force,
                                                                                  out: flags["out"] ?? WubDefaults.packPath("ableton/performance-sets/BASS_PERFORMANCE_SET_v1.0.als"),
                                                                                  anchorsPack: flags["anchors_pack"],
                                                                                  minBytes: 200000,
                                                                                  warnBytes: 1000000,
                                                                                  dryRun: false,
                                                                                  overwrite: flags["overwrite"] == "true",
                                                                                  preflight: true,
                                                                                  runsDir: config.runsDir,
                                                                                  regionsConfig: "kernel/cli/config/regions.v1.json"))
      return CommandExecutionResult(exitCode: receipt.status == "fail" ? 1 : 0, notes: nil)

    case "assets.export_finishing_bays":
      let receipt = try await AssetsExportFinishingBaysService.run(config: .init(force: config.force,
                                                                                spec: flags["spec"] ?? WubDefaults.profileSpecPath("assets/export/finishing_bays_export.v1.yaml"),
                                                                                anchorsPack: flags["anchors_pack"],
                                                                                minBytes: 200000,
                                                                                warnBytes: 1000000,
                                                                                overwrite: flags["overwrite"] == "true",
                                                                                promptEach: false,
                                                                                preflight: true,
                                                                                runsDir: config.runsDir,
                                                                                regionsConfig: "kernel/cli/config/regions.v1.json"))
      return CommandExecutionResult(exitCode: receipt.status == "fail" ? 1 : 0, notes: nil)

    case "assets.export_serum_base":
      let receipt = try await AssetsExportSerumBaseService.run(config: .init(force: config.force,
                                                                             out: flags["out"] ?? "library/serum/SERUM_BASE_v1.0.fxp",
                                                                             anchorsPack: flags["anchors_pack"],
                                                                             minBytes: 5000,
                                                                             warnBytes: 20000,
                                                                             overwrite: flags["overwrite"] == "true",
                                                                             preflight: true,
                                                                             runsDir: config.runsDir,
                                                                             regionsConfig: "kernel/cli/config/regions.v1.json"))
      return CommandExecutionResult(exitCode: receipt.status == "fail" ? 1 : 0, notes: nil)

    case "assets.export_all":
      let receipt = try await AssetsService.exportAll(config: .init(anchorsPack: flags["anchors_pack"],
                                                                    overwrite: flags["overwrite"] == "true",
                                                                    nonInteractive: true,
                                                                    preflight: true,
                                                                    runsDir: config.runsDir,
                                                                    regionsConfig: "kernel/cli/config/regions.v1.json",
                                                                    racksOut: WubDefaults.packPath("ableton/racks/BASS_RACKS"),
                                                                    performanceOut: WubDefaults.packPath("ableton/performance-sets/BASS_PERFORMANCE_SET_v1.0.als"),
                                                                    baysSpec: WubDefaults.profileSpecPath("assets/export/finishing_bays_export.v1.yaml"),
                                                                    serumOut: "library/serum/SERUM_BASE_v1.0.fxp",
                                                                    extrasSpec: WubDefaults.profileSpecPath("assets/export/extra_exports.v1.yaml"),
                                                                    postcheck: true,
                                                                    rackVerifyManifest: WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json"),
                                                                    vrlMapping: WubDefaults.profileSpecPath("voice/runtime/vrl_mapping.v1.yaml"),
                                                                    force: config.force))
      return CommandExecutionResult(exitCode: receipt.status == "fail" ? 1 : 0, notes: nil)

    default:
      return CommandExecutionResult(exitCode: 1, notes: "unsupported_service")
    }
  }

  private static func parseFlags(_ tokens: [String]) -> [String: String] {
    var out: [String: String] = [:]
    for t in tokens {
      let parts = t.split(separator: "=", maxSplits: 1).map(String.init)
      if parts.count == 2 {
        out[parts[0]] = parts[1]
      }
    }
    return out
  }
}
