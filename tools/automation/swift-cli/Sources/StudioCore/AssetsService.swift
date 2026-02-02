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

    var steps: [AssetsExportStepV1] = []
    var reasons: [String] = []
    var artifacts: [String: String] = [:]

    func recordStep(id: String, command: String, exitCode: Int) {
      steps.append(.init(id: id, command: command, exitCode: exitCode))
      if exitCode != 0 { reasons.append("\(id): exit=\(exitCode)") }
    }

    let racksExit: Int
    do {
      let receipt = try await AssetsExportRacksService.run(config: .init(force: config.force,
                                                                          manifest: config.rackVerifyManifest,
                                                                          outDir: config.racksOut,
                                                                          anchorsPack: config.anchorsPack,
                                                                          minBytes: 20000,
                                                                          warnBytes: 80000,
                                                                          overwrite: config.overwrite ? "always" : (config.nonInteractive ? "never" : "ask"),
                                                                          dryRun: false,
                                                                          interactive: !config.nonInteractive,
                                                                          preflight: config.preflight,
                                                                          runsDir: config.runsDir,
                                                                          regionsConfig: config.regionsConfig))
      racksExit = (receipt.status == "fail") ? 1 : 0
      if racksExit != 0 { reasons.append("export_racks: status=\(receipt.status)") }
    } catch {
      reasons.append("export_racks: \(error.localizedDescription)")
      racksExit = 999
    }
    recordStep(id: "export_racks", command: "service: assets.export_racks", exitCode: racksExit)
    artifacts["racks_out_dir"] = config.racksOut

    if config.postcheck {
      if FileManager.default.fileExists(atPath: config.rackVerifyManifest) {
        let verifyExit: Int
        do {
          let receipt = try await RackVerifyService.verify(config: .init(manifest: config.rackVerifyManifest,
                                                                         macroRegion: "rack.macros",
                                                                         runApply: true,
                                                                         anchorsPack: config.anchorsPack,
                                                                         runsDir: config.runsDir))
          verifyExit = (receipt.status == "pass") ? 0 : 1
          if verifyExit != 0 { reasons.append("verify_racks: status=\(receipt.status)") }
        } catch {
          reasons.append("verify_racks: \(error.localizedDescription)")
          verifyExit = 999
        }
        recordStep(id: "verify_racks", command: "service: rack.verify", exitCode: verifyExit)
      } else {
        reasons.append("verify_racks: missing manifest \(config.rackVerifyManifest)")
        recordStep(id: "verify_racks", command: "service: rack.verify", exitCode: 1)
      }
    }

    let perfExit: Int
    do {
      let receipt = try await AssetsExportPerformanceSetService.run(config: .init(force: config.force,
                                                                                  out: config.performanceOut,
                                                                                  anchorsPack: config.anchorsPack,
                                                                                  minBytes: 200000,
                                                                                  warnBytes: 1000000,
                                                                                  dryRun: false,
                                                                                  overwrite: config.overwrite,
                                                                                  preflight: config.preflight,
                                                                                  runsDir: config.runsDir,
                                                                                  regionsConfig: config.regionsConfig))
      perfExit = (receipt.status == "fail") ? 1 : 0
      if perfExit != 0 { reasons.append("export_performance_set: status=\(receipt.status)") }
    } catch {
      reasons.append("export_performance_set: \(error.localizedDescription)")
      perfExit = 999
    }
    recordStep(id: "export_performance_set", command: "service: assets.export_performance_set", exitCode: perfExit)
    artifacts["performance_set_out"] = config.performanceOut

    if config.postcheck {
      if FileManager.default.fileExists(atPath: config.vrlMapping) {
        let vrlExit: Int
        do {
          let receipt = try await VRLService.validate(config: .init(mapping: config.vrlMapping,
                                                                    regions: config.regionsConfig,
                                                                    out: nil,
                                                                    dump: false,
                                                                    runsDir: config.runsDir))
          vrlExit = (receipt.status == "fail") ? 1 : 0
          if vrlExit != 0 { reasons.append("vrl_validate: status=\(receipt.status)") }
        } catch {
          reasons.append("vrl_validate: \(error.localizedDescription)")
          vrlExit = 999
        }
        recordStep(id: "vrl_validate", command: "service: vrl.validate", exitCode: vrlExit)
      } else {
        reasons.append("vrl_validate: missing mapping \(config.vrlMapping)")
        recordStep(id: "vrl_validate", command: "service: vrl.validate", exitCode: 1)
      }
    }

    let baysExit: Int
    do {
      let receipt = try await AssetsExportFinishingBaysService.run(config: .init(force: config.force,
                                                                                spec: config.baysSpec,
                                                                                anchorsPack: config.anchorsPack,
                                                                                minBytes: 200000,
                                                                                warnBytes: 1000000,
                                                                                overwrite: config.overwrite,
                                                                                promptEach: !config.nonInteractive,
                                                                                preflight: config.preflight,
                                                                                runsDir: config.runsDir,
                                                                                regionsConfig: config.regionsConfig))
      baysExit = (receipt.status == "fail") ? 1 : 0
      if baysExit != 0 { reasons.append("export_finishing_bays: status=\(receipt.status)") }
    } catch {
      reasons.append("export_finishing_bays: \(error.localizedDescription)")
      baysExit = 999
    }
    recordStep(id: "export_finishing_bays", command: "service: assets.export_finishing_bays", exitCode: baysExit)
    artifacts["finishing_bays_spec"] = config.baysSpec

    let serumExit: Int
    do {
      let receipt = try await AssetsExportSerumBaseService.run(config: .init(force: config.force,
                                                                             out: config.serumOut,
                                                                             anchorsPack: config.anchorsPack,
                                                                             minBytes: 5000,
                                                                             warnBytes: 20000,
                                                                             overwrite: config.overwrite,
                                                                             preflight: config.preflight,
                                                                             runsDir: config.runsDir,
                                                                             regionsConfig: config.regionsConfig))
      serumExit = (receipt.status == "fail") ? 1 : 0
      if serumExit != 0 { reasons.append("export_serum_base: status=\(receipt.status)") }
    } catch {
      reasons.append("export_serum_base: \(error.localizedDescription)")
      serumExit = 999
    }
    recordStep(id: "export_serum_base", command: "service: assets.export_serum_base", exitCode: serumExit)
    artifacts["serum_base_out"] = config.serumOut

    let extrasExit: Int
    do {
      let receipt = try await AssetsExportExtrasService.run(config: .init(force: config.force,
                                                                          spec: config.extrasSpec,
                                                                          anchorsPack: config.anchorsPack,
                                                                          minBytes: 20000,
                                                                          warnBytes: 80000,
                                                                          overwrite: config.overwrite,
                                                                          preflight: config.preflight,
                                                                          runsDir: config.runsDir,
                                                                          regionsConfig: config.regionsConfig))
      extrasExit = (receipt.status == "fail") ? 1 : 0
      if extrasExit != 0 { reasons.append("export_extras: status=\(receipt.status)") }
    } catch {
      reasons.append("export_extras: \(error.localizedDescription)")
      extrasExit = 999
    }
    recordStep(id: "export_extras", command: "service: assets.export_extras", exitCode: extrasExit)
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

}
