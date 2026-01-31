import Foundation
import ArgumentParser

extension Assets {
  struct ExportAll: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "export-all",
      abstract: "Run the full repo completeness export pipeline (racks, performance set, finishing bays, serum base, extras)."
    )

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Anchors pack passed to apply in subcommands.")
    var anchorsPack: String?

    @Flag(name: .long, help: "Overwrite existing outputs when supported.")
    var overwrite: Bool = false

    @Flag(name: .long, help: "Skip interactive prompts (uses safe defaults).")
    var nonInteractive: Bool = false

    @Option(name: .long, help: "Output directory for racks export.")
    var racksOut: String = "ableton/racks/BASS_RACKS_v1.0"

    @Option(name: .long, help: "Target path for performance set export.")
    var performanceOut: String = "ableton/performance-sets/HVLIEN_BASS_PERFORMANCE_SET_v1.0.als"

    @Option(name: .long, help: "Spec file for finishing bays export.")
    var baysSpec: String = "specs/assets/export/finishing_bays_export.v1.yaml"

    @Option(name: .long, help: "Target path for Serum base export.")
    var serumOut: String = "library/serum/HVLIEN_SERUM_BASE_v1.0.fxp"

    @Option(name: .long, help: "Spec file for extra exports.")
    var extrasSpec: String = "specs/assets/export/extra_exports.v1.yaml"

    func run() async throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

      let exe = CommandLine.arguments.first ?? "hvlien"
      var steps: [AssetsExportStepV1] = []
      var reasons: [String] = []
      var artifacts: [String: String] = [:]

      @discardableResult
      func step(_ id: String, _ args: [String]) async -> Int32 {
        let cmd = ([exe] + args).joined(separator: " ")
        let code: Int32
        do { code = try await runProcess(exe: exe, args: args) }
        catch { steps.append(.init(id: id, command: cmd, exitCode: 999)); reasons.append("\(id): error"); return 999 }
        steps.append(.init(id: id, command: cmd, exitCode: Int(code)))
        if code != 0 { reasons.append("\(id): exit=\(code)") }
        return code
      }

      // 1) export racks
      var racksArgs = ["assets","export-racks","--out-dir", racksOut]
      if let ap = anchorsPack { racksArgs += ["--anchors-pack", ap] }
      if overwrite { racksArgs += ["--overwrite", "always"] } else { racksArgs += ["--overwrite", nonInteractive ? "never" : "ask"] }
      if nonInteractive { racksArgs += ["--interactive=false"] } // ArgumentParser bool flag; safe if ignored
      _ = await step("export_racks", racksArgs)
      artifacts["racks_out_dir"] = racksOut

      // 2) export performance set
      var perfArgs = ["assets","export-performance-set","--out", performanceOut]
      if let ap = anchorsPack { perfArgs += ["--anchors-pack", ap] }
      if overwrite { perfArgs += ["--overwrite"] }
      _ = await step("export_performance_set", perfArgs)
      artifacts["performance_set_out"] = performanceOut

      // 3) export finishing bays
      var baysArgs = ["assets","export-finishing-bays","--spec", baysSpec]
      if let ap = anchorsPack { baysArgs += ["--anchors-pack", ap] }
      if overwrite { baysArgs += ["--overwrite"] }
      if nonInteractive { baysArgs += ["--prompt-each=false"] } // safe if ignored depending on parser
      _ = await step("export_finishing_bays", baysArgs)
      artifacts["finishing_bays_spec"] = baysSpec

      // 4) export serum base
      var serumArgs = ["assets","export-serum-base","--out", serumOut]
      if let ap = anchorsPack { serumArgs += ["--anchors-pack", ap] }
      if overwrite { serumArgs += ["--overwrite"] }
      _ = await step("export_serum_base", serumArgs)
      artifacts["serum_base_out"] = serumOut

      // 5) export extras
      var extrasArgs = ["assets","export-extras","--spec", extrasSpec]
      if let ap = anchorsPack { extrasArgs += ["--anchors-pack", ap] }
      if overwrite { extrasArgs += ["--overwrite"] }
      _ = await step("export_extras", extrasArgs)
      artifacts["extras_spec"] = extrasSpec

      let hasFail = reasons.contains(where: { $0.contains("exit=") && !$0.contains("exit=0") })
      let status = hasFail ? "fail" : "pass"

      let receipt = AssetsExportAllReceiptV1(schemaVersion: 1,
                                            runId: runId,
                                            timestamp: ISO8601DateFormatter().string(from: Date()),
                                            job: "assets_export_all",
                                            status: status,
                                            steps: steps,
                                            artifacts: artifacts.merging(["run_dir": "runs/\(runId)"]) { a, _ in a },
                                            reasons: reasons)
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("assets_export_all_receipt.v1.json"))
      print("receipt: runs/\(runId)/assets_export_all_receipt.v1.json")
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
