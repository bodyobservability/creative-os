import Foundation
import ArgumentParser

struct RepairService {
  struct Config {
    let force: Bool
    let anchorsPackHint: String
    let yes: Bool
    let overwrite: Bool
    let runsDir: String
  }

  static func run(config: Config) async throws -> RepairReceiptV1? {
    try StationGate.enforceOrThrow(force: config.force,
                                  anchorsPackHint: config.anchorsPackHint,
                                  commandName: "repair")

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let plan = [
      "service: assets.export_all",
      "service: index.build",
      "service: drift.check",
      "service: drift.fix"
    ]

    print("REPAIR PLAN (v1)")
    for p in plan { print("- " + p) }

    if !config.yes {
      print("\nProceed with repair recipe? [y/N] ", terminator: "")
      let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
      if ans != "y" && ans != "yes" { return nil }
    }

    var steps: [RepairStepV1] = []
    var reasons: [String] = []
    var status: String = "pass"

    @discardableResult
    func step(_ id: String, _ command: String, _ action: () async throws -> Int32) async -> Int32 {
      let code: Int32
      do { code = try await action() }
      catch {
        steps.append(.init(id: id, command: command, exitCode: 999))
        reasons.append("\(id): \(error.localizedDescription)")
        status = "fail"
        return 999
      }
      steps.append(.init(id: id, command: command, exitCode: Int(code)))
      if code != 0 {
        reasons.append("\(id): exit=\(code)")
        if status == "pass" { status = "fail" }
      }
      return code
    }

    let exportCode = await step("export_all", "service: assets.export_all") {
      let receipt = try await AssetsService.exportAll(config: .init(anchorsPack: config.anchorsPackHint,
                                                                    overwrite: config.overwrite,
                                                                    nonInteractive: true,
                                                                    preflight: true,
                                                                    runsDir: config.runsDir,
                                                                    regionsConfig: "tools/automation/swift-cli/config/regions.v1.json",
                                                                    racksOut: WubDefaults.packPath("ableton/racks/BASS_RACKS_v1.0"),
                                                                    performanceOut: WubDefaults.packPath("ableton/performance-sets/BASS_PERFORMANCE_SET_v1.0.als"),
                                                                    baysSpec: WubDefaults.profileSpecPath("assets/export/finishing_bays_export.v1.yaml"),
                                                                    serumOut: "library/serum/SERUM_BASE_v1.0.fxp",
                                                                    extrasSpec: WubDefaults.profileSpecPath("assets/export/extra_exports.v1.yaml"),
                                                                    postcheck: true,
                                                                    rackVerifyManifest: WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json"),
                                                                    vrlMapping: WubDefaults.profileSpecPath("voice/runtime/vrl_mapping.v1.yaml"),
                                                                    force: config.force))
      return receipt.status == "fail" ? 1 : 0
    }
    if exportCode != 0 {
      return finalize(runId: runId, runDir: runDir, steps: steps, reasons: reasons, status: status, runsDir: config.runsDir)
    }

    let indexCode = await step("index_build", "service: index.build") {
      _ = try IndexService.build(config: .init(repoVersion: "current",
                                               outDir: "checksums/index",
                                               runsDir: config.runsDir))
      return 0
    }
    if indexCode != 0 {
      return finalize(runId: runId, runDir: runDir, steps: steps, reasons: reasons, status: status, runsDir: config.runsDir)
    }

    let driftCode = await step("drift_check", "service: drift.check") {
      _ = try DriftService.check(config: .init(artifactIndex: "checksums/index/artifact_index.v1.json",
                                               receiptIndex: "checksums/index/receipt_index.v1.json",
                                               anchorsPackHint: config.anchorsPackHint,
                                               out: nil,
                                               format: "human",
                                               groupByFix: true,
                                               onlyFail: false))
      return 0
    }
    if driftCode != 0 {
      let fixCode = await step("drift_fix", "service: drift.fix") {
        let receipt = try await DriftFixService.run(config: .init(force: config.force,
                                                                  artifactIndex: "checksums/index/artifact_index.v1.json",
                                                                  receiptIndex: "checksums/index/receipt_index.v1.json",
                                                                  anchorsPackHint: config.anchorsPackHint,
                                                                  yes: config.yes,
                                                                  dryRun: false,
                                                                  out: nil,
                                                                  runsDir: config.runsDir))
        return receipt.status == "fail" ? 1 : 0
      }
      if fixCode == 0 && status == "fail" { status = "warn" }
    }

    return finalize(runId: runId, runDir: runDir, steps: steps, reasons: reasons, status: status, runsDir: config.runsDir)
  }

  private static func finalize(runId: String,
                               runDir: URL,
                               steps: [RepairStepV1],
                               reasons: [String],
                               status: String,
                               runsDir: String) -> RepairReceiptV1 {
    let receipt = RepairReceiptV1(schemaVersion: 1,
                                  runId: runId,
                                  timestamp: ISO8601DateFormatter().string(from: Date()),
                                  status: status,
                                  steps: steps,
                                  reasons: reasons)
    try? JSONIO.save(receipt, to: runDir.appendingPathComponent("repair_receipt.v1.json"))
    print("receipt: \(runsDir)/\(runId)/repair_receipt.v1.json")
    return receipt
  }

}
