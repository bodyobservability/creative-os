import Foundation
import ArgumentParser

struct RackVerifyService {
  struct Config {
    let manifest: String
    let macroRegion: String
    let runApply: Bool
    let anchorsPack: String?
    let runsDir: String
  }

  static func verify(config: Config) async throws -> RackComplianceReceiptV1 {
    var common = CommonOptions()
    common.runsDir = config.runsDir
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()

    let runDir = ctx.runDir
    let data = try Data(contentsOf: URL(fileURLWithPath: config.manifest))
    let mf = try JSONDecoder().decode(RackPackManifestV1.self, from: data)

    let planObj = RackVerify.generatePlan(manifest: mf, macroRegion: config.macroRegion)
    let planPath = runDir.appendingPathComponent("rack_verify.plan.v1.json")
    let planData = try JSONSerialization.data(withJSONObject: planObj, options: [.prettyPrinted, .sortedKeys])
    try planData.write(to: planPath)

    var applyExit: Int32 = 0
    if config.runApply {
      let exe = CommandLine.arguments.first ?? "wub"
      var args = ["apply", "--plan", planPath.path]
      if let ap = config.anchorsPack { args += ["--anchors-pack", ap] }
      args += ["--allow-cgevent"]
      applyExit = try await runProcess(exe: exe, args: args)
    }

    let results = mf.racks.map { RackComplianceReceiptV1.RackResult(rackId: $0.rackId,
                                                                   trackHint: RackVerify.guessTrackHint(rack: $0),
                                                                   status: (applyExit == 0 ? "unknown" : "unknown"),
                                                                   notes: $0.notes) }
    let status = (applyExit == 0) ? "pass" : "fail"
    let receipt = RackComplianceReceiptV1(schemaVersion: 1,
                                          runId: ctx.runId,
                                          timestamp: ISO8601DateFormatter().string(from: Date()),
                                          manifestPath: config.manifest,
                                          status: status,
                                          planPath: "\(config.runsDir)/\(ctx.runId)/rack_verify.plan.v1.json",
                                          applyReceiptPath: config.runApply ? "\(config.runsDir)/\(ctx.runId)/receipt.v1.json" : nil,
                                          applyTracePath: config.runApply ? "\(config.runsDir)/\(ctx.runId)/trace.v1.json" : nil,
                                          results: results,
                                          reasons: (applyExit == 0 ? [] : ["apply_exit=\(applyExit)"]))
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("rack_receipt.v1.json"))

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
