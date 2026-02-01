import Foundation
import ArgumentParser

extension Drift {
  struct Fix: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "fix",
      abstract: "Execute the drift remediation plan with guarded prompts and emit a fix receipt (v1.8.4)."
    )

    @Flag(name: .long, help: "Override station gating (dangerous).")
    var force: Bool = false

    @Option(name: .long) var artifactIndex: String = "checksums/index/artifact_index.v1.json"
    @Option(name: .long) var receiptIndex: String = "checksums/index/receipt_index.v1.json"
    @Option(name: .long) var anchorsPackHint: String = "specs/automation/anchors/<pack_id>"

    @Flag(name: .long, help: "Skip per-command prompts; still requires one final confirmation.")
    var yes: Bool = false

    @Flag(name: .long, help: "Print commands that would run, but do not execute.")
    var dryRun: Bool = false

    @Option(name: .long, help: "Output receipt path (default runs/<run_id>/drift_fix_receipt.v1.json).")
    var out: String?

    func run() async throws {
      try StationGate.enforceOrThrow(force: force, anchorsPackHint: anchorsPackHint, commandName: "drift fix")

      // Build current drift recommended fixes (same logic as drift plan)
      let aidx = try JSONIO.load(ArtifactIndexV1.self, from: URL(fileURLWithPath: artifactIndex))
      let ridx = try JSONIO.load(ReceiptIndexV1.self, from: URL(fileURLWithPath: receiptIndex))
      let budgets = DriftEvaluator.Budgets(staleWarnAfterS: 24*3600, staleFailAfterS: 7*24*3600, placeholderFail: true)
      let fixes = FixCatalog(anchorsPackHint: anchorsPackHint)

      let base = DriftEvaluator.evaluate(artifactIndex: aidx, receiptIndex: ridx, budgets: budgets, suggestedFixes: fixes)
      let findings: [DriftReportV2.Finding] = base.findings.map { f in
        DriftReportV2.Finding(id: f.id, severity: f.severity, kind: f.kind, artifactPath: f.artifactPath, title: f.title, why: f.why, fix: f.fix, details: f.details)
      }
      let recommended = DriftPlanner.recommendFixes(findings: findings)
      let commands = recommended.map { $0.command }.filter { !$0.isEmpty }

      let runId = RunContext.makeRunId()
      let ts = ISO8601DateFormatter().string(from: Date())
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
      let outPath = out ?? runDir.appendingPathComponent("drift_fix_receipt.v1.json").path

      if commands.isEmpty {
        let receipt = DriftFixReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, status: "pass", plan: [], steps: [], reasons: ["no_fixes_needed"])
        try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))
        print("No fixes needed.")
        print("receipt: \(outPath)")
        return
      }

      print("DRIFT FIX (v1.8.4)")
      print("Plan commands (\(commands.count)):\n")
      for c in commands { print("  " + c) }
      print("")

      if dryRun {
        let receipt = DriftFixReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, status: "pass", plan: commands, steps: [], reasons: ["dry_run"])
        try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))
        print("DRY RUN only. receipt: \(outPath)")
        return
      }

      // Final confirmation
      if !yes {
        print("Proceed to execute these commands? [y/N] ", terminator: "")
        let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if ans != "y" && ans != "yes" {
          let receipt = DriftFixReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, status: "aborted", plan: commands, steps: [], reasons: ["aborted_by_user"])
          try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))
          print("Aborted. receipt: \(outPath)")
          throw ExitCode(2)
        }
      }

      // Execute sequentially
      var steps: [DriftFixStepV1] = []
      var reasons: [String] = []
      var overallStatus = "pass"

      for (i, cmd) in commands.enumerated() {
        if !yes {
          print("\nRun now? [y/N]  \(cmd)\n> ", terminator: "")
          let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
          if ans != "y" && ans != "yes" {
            steps.append(.init(id: "step_\(i+1)", command: cmd, exitCode: 0, notes: "skipped_by_user"))
            overallStatus = (overallStatus == "fail") ? "fail" : "warn"
            continue
          }
        }

        let exit = try await runShell(cmd: cmd)
        steps.append(.init(id: "step_\(i+1)", command: cmd, exitCode: Int(exit), notes: nil))
        if exit != 0 {
          reasons.append("command_failed(step_\(i+1))")
          overallStatus = "fail"
          break
        }
      }

      let receipt = DriftFixReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, status: overallStatus, plan: commands, steps: steps, reasons: reasons)
      try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))
      print("\nreceipt: \(outPath)")
      if overallStatus == "fail" { throw ExitCode(1) }
    }

    private func runShell(cmd: String) async throws -> Int32 {
      return try await withCheckedThrowingContinuation { cont in
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-lc", cmd]
        p.standardOutput = FileHandle.standardOutput
        p.standardError = FileHandle.standardError
        p.terminationHandler = { proc in cont.resume(returning: proc.terminationStatus) }
        do { try p.run() } catch { cont.resume(throwing: error) }
      }
    }
  }
}
