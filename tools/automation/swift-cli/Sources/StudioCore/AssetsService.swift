import Foundation
import ArgumentParser

struct AssetsService {
  struct ExportAllConfig {
    let anchorsPack: String?
    let overwrite: Bool
    let nonInteractive: Bool
    let preflight: Bool
    let runsDir: String
    let regionsConfig: String
    let racksOut: String
    let performanceOut: String
    let baysSpec: String
    let serumOut: String
    let extrasSpec: String
    let postcheck: Bool
    let rackVerifyManifest: String
    let vrlMapping: String
    let force: Bool
  }

  static func exportAll(config: ExportAllConfig) async throws -> AssetsExportAllReceiptV1 {
    try StationGate.enforceOrThrow(force: config.force, anchorsPackHint: config.anchorsPack, commandName: "assets export-all")

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    if config.preflight {
      var common = CommonOptions()
      common.regionsConfig = config.regionsConfig
      common.runsDir = config.runsDir
      let report = try await ExportPreflightRunner.run(common: common,
                                                       anchorsPack: config.anchorsPack,
                                                       runId: runId,
                                                       runDir: runDir)
      if report.status == "fail" { throw ExitCode(2) }
    }

    let exe = CommandLine.arguments.first ?? "wub"
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

    var racksArgs = ["assets","export-racks","--out-dir", config.racksOut]
    if let ap = config.anchorsPack { racksArgs += ["--anchors-pack", ap] }
    if config.overwrite { racksArgs += ["--overwrite", "always"] } else { racksArgs += ["--overwrite", config.nonInteractive ? "never" : "ask"] }
    if config.nonInteractive { racksArgs += ["--interactive=false"] }
    _ = await step("export_racks", racksArgs)
    artifacts["racks_out_dir"] = config.racksOut

    if config.postcheck {
      if FileManager.default.fileExists(atPath: config.rackVerifyManifest) {
        var verifyArgs = ["rack","verify","--manifest", config.rackVerifyManifest]
        if let ap = config.anchorsPack { verifyArgs += ["--anchors-pack", ap] }
        _ = await step("verify_racks", verifyArgs)
      } else {
        reasons.append("verify_racks: missing manifest \(config.rackVerifyManifest)")
      }
    }

    var perfArgs = ["assets","export-performance-set","--out", config.performanceOut]
    if let ap = config.anchorsPack { perfArgs += ["--anchors-pack", ap] }
    if config.overwrite { perfArgs += ["--overwrite"] }
    _ = await step("export_performance_set", perfArgs)
    artifacts["performance_set_out"] = config.performanceOut

    if config.postcheck {
      if FileManager.default.fileExists(atPath: config.vrlMapping) {
        let vrlArgs = ["vrl","validate","--mapping", config.vrlMapping, "--regions", config.regionsConfig]
        _ = await step("vrl_validate", vrlArgs)
      } else {
        reasons.append("vrl_validate: missing mapping \(config.vrlMapping)")
      }
    }

    var baysArgs = ["assets","export-finishing-bays","--spec", config.baysSpec]
    if let ap = config.anchorsPack { baysArgs += ["--anchors-pack", ap] }
    if config.overwrite { baysArgs += ["--overwrite"] }
    if config.nonInteractive { baysArgs += ["--prompt-each=false"] }
    _ = await step("export_finishing_bays", baysArgs)
    artifacts["finishing_bays_spec"] = config.baysSpec

    var serumArgs = ["assets","export-serum-base","--out", config.serumOut]
    if let ap = config.anchorsPack { serumArgs += ["--anchors-pack", ap] }
    if config.overwrite { serumArgs += ["--overwrite"] }
    _ = await step("export_serum_base", serumArgs)
    artifacts["serum_base_out"] = config.serumOut

    var extrasArgs = ["assets","export-extras","--spec", config.extrasSpec]
    if let ap = config.anchorsPack { extrasArgs += ["--anchors-pack", ap] }
    if config.overwrite { extrasArgs += ["--overwrite"] }
    _ = await step("export_extras", extrasArgs)
    artifacts["extras_spec"] = config.extrasSpec

    let hasFail = reasons.contains(where: { $0.contains("exit=") && !$0.contains("exit=0") })
    let status = hasFail ? "fail" : "pass"
    let receipt = AssetsExportAllReceiptV1(schemaVersion: 1,
                                           runId: runId,
                                           timestamp: ISO8601DateFormatter().string(from: Date()),
                                           job: "assets_export_all",
                                           status: status,
                                           steps: steps,
                                           artifacts: artifacts.merging(["run_dir": "\(config.runsDir)/\(runId)"]) { a, _ in a },
                                           reasons: reasons)
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("assets_export_all_receipt.v1.json"))

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
