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

    let exe = CommandLine.arguments.first ?? "wub"
    var gates: [PromotionGateResult] = []
    var reasons: [String] = []

    let profileId = inferProfileId(from: config.profile)
    let certifyArgs = ["sonic", "certify", "--baseline", config.baseline, "--sweep", config.currentSweep,
                       "--rack-id", config.rackId, "--profile-id", profileId, "--macro", config.macro]
    let certifyExit = await runProcess(exe: exe, args: certifyArgs)
    gates.append(.init(id: "sonic_certify", command: ([exe] + certifyArgs).joined(separator: " "), exitCode: Int(certifyExit)))
    if certifyExit != 0 { reasons.append("sonic_certify failed") }

    if FileManager.default.fileExists(atPath: config.rackManifest) {
      let rvArgs = ["rack", "verify", "--manifest", config.rackManifest, "--macro-region", "rack.macros"]
      let rvExit = await runProcess(exe: exe, args: rvArgs)
      gates.append(.init(id: "rack_verify", command: ([exe] + rvArgs).joined(separator: " "), exitCode: Int(rvExit)))
      if rvExit != 0 { reasons.append("rack_verify failed") }
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

  private static func runProcess(exe: String, args: [String]) async -> Int32 {
    await withCheckedContinuation { cont in
      let p = Process()
      p.executableURL = URL(fileURLWithPath: exe)
      p.arguments = args
      p.standardOutput = FileHandle.standardOutput
      p.standardError = FileHandle.standardError
      p.terminationHandler = { proc in cont.resume(returning: proc.terminationStatus) }
      do { try p.run() } catch { cont.resume(returning: 999) }
    }
  }
}
