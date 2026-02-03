import Foundation
import ArgumentParser

struct RackInstallService {
  struct Config {
    let manifest: String
    let macroRegion: String
    let anchorsPack: String?
    let allowCgevent: Bool
    let runsDir: String
  }

  static func install(config: Config) async throws -> RackInstallReceiptV1 {
    var common = CommonOptions()
    common.runsDir = config.runsDir
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()
    let runDir = ctx.runDir

    let mf = try JSONDecoder().decode(RackPackManifestV1.self, from: Data(contentsOf: URL(fileURLWithPath: config.manifest)))

    let planObj = RackInstall.generateInstallPlan(manifest: mf, macroRegion: config.macroRegion)
    let planPath = runDir.appendingPathComponent("rack_install.plan.v1.json")
    let planData = try JSONSerialization.data(withJSONObject: planObj, options: [.prettyPrinted, .sortedKeys])
    try planData.write(to: planPath)

    let exe = CommandLine.arguments.first ?? "wub"
    var args = ["apply", "--plan", planPath.path]
    if let ap = config.anchorsPack { args += ["--anchors-pack", ap] }
    if config.allowCgevent { args += ["--allow-cgevent"] }
    let applyExit = try await runProcess(exe: exe, args: args)

    let installed = mf.racks.map { RackInstallReceiptV1.InstalledRack(rackId: $0.rackId,
                                                                      targetTrack: $0.targetTrack ?? RackVerify.guessTrackHint(rack: $0) ?? "Track",
                                                                      decision: (applyExit == 0 ? "attempted" : "failed"),
                                                                      notes: $0.notes) }
    let status = (applyExit == 0) ? "pass" : "fail"
    let receipt = RackInstallReceiptV1(schemaVersion: 1,
                                       runId: ctx.runId,
                                       timestamp: ISO8601DateFormatter().string(from: Date()),
                                       manifestPath: config.manifest,
                                       status: status,
                                       planPath: "\(config.runsDir)/\(ctx.runId)/rack_install.plan.v1.json",
                                       applyReceiptPath: "\(config.runsDir)/\(ctx.runId)/receipt.v1.json",
                                       applyTracePath: "\(config.runsDir)/\(ctx.runId)/trace.v1.json",
                                       installed: installed,
                                       reasons: (applyExit == 0 ? [] : ["apply_exit=\(applyExit)"]))
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("rack_install_receipt.v1.json"))

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
