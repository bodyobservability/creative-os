import Foundation

struct ReleaseService {
  struct PromoteConfig {
    let profile: String
    let out: String?
    let rackId: String
    let macro: String
    let baseline: String
    let currentSweep: String
    let rackManifest: String
    let runsDir: String
  }

  static func promoteProfile(config: PromoteConfig) async throws -> ProfilePromotionReceiptV1 {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    var gates: [PromotionGateResult] = []
    var reasons: [String] = []

    let profileId = inferProfileId(from: config.profile)
    let certifyExit: Int
    do {
      let receipt = try await SonicCertifyService.run(config: .init(baseline: config.baseline,
                                                                    sweep: config.currentSweep,
                                                                    rackId: config.rackId,
                                                                    profileId: profileId,
                                                                    macro: config.macro,
                                                                    runsDir: config.runsDir))
      certifyExit = (receipt.status == "pass") ? 0 : 1
      gates.append(.init(id: "sonic_certify", command: "service: sonic.certify", exitCode: certifyExit))
      if certifyExit != 0 { reasons.append("sonic_certify failed") }
    } catch {
      certifyExit = 999
      gates.append(.init(id: "sonic_certify", command: "service: sonic.certify", exitCode: certifyExit))
      reasons.append("sonic_certify error: \(error.localizedDescription)")
    }

    if FileManager.default.fileExists(atPath: config.rackManifest) {
      let rvExit: Int
      do {
        let receipt = try await RackVerifyService.verify(config: .init(manifest: config.rackManifest,
                                                                       macroRegion: "rack.macros",
                                                                       runApply: true,
                                                                       anchorsPack: nil,
                                                                       runsDir: config.runsDir))
        rvExit = (receipt.status == "pass") ? 0 : 1
        gates.append(.init(id: "rack_verify", command: "service: rack.verify", exitCode: rvExit))
        if rvExit != 0 { reasons.append("rack_verify failed") }
      } catch {
        rvExit = 999
        gates.append(.init(id: "rack_verify", command: "service: rack.verify", exitCode: rvExit))
        reasons.append("rack_verify error: \(error.localizedDescription)")
      }
    } else {
      gates.append(.init(id: "rack_verify", command: "skipped (manifest missing)", exitCode: 0))
    }

    let status = reasons.isEmpty ? "pass" : "fail"
    let outPath = config.out ?? defaultReleasePath(for: config.profile)

    if status == "pass" {
      try FileManager.default.createDirectory(at: URL(fileURLWithPath: (outPath as NSString).deletingLastPathComponent), withIntermediateDirectories: true)
      if FileManager.default.fileExists(atPath: outPath) { try FileManager.default.removeItem(atPath: outPath) }
      try FileManager.default.copyItem(atPath: config.profile, toPath: outPath)
    }

    let receipt = ProfilePromotionReceiptV1(schemaVersion: 1,
                                            runId: runId,
                                            timestamp: ISO8601DateFormatter().string(from: Date()),
                                            profileIn: config.profile,
                                            profileOut: outPath,
                                            status: status,
                                            gates: gates,
                                            reasons: reasons)
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("profile_promotion_receipt.v1.json"))

    return receipt
  }

  private static func inferProfileId(from path: String) -> String {
    let u = URL(fileURLWithPath: path)
    return u.deletingPathExtension().lastPathComponent
  }

  private static func defaultReleasePath(for profile: String) -> String {
    let u = URL(fileURLWithPath: profile)
    return WubDefaults.profileSpecPath("library/profiles/release/\(u.lastPathComponent)")
  }

}
