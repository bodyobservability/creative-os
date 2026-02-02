import Foundation
import ArgumentParser
import Yams

struct SessionService {
  struct Config {
    let profile: String
    let profilePath: String?
    let anchorsPack: String?
    let fix: Bool
    let runsDir: String
  }

  static func compile(config: Config) async throws -> SessionReceiptV1 {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let profPath = config.profilePath ?? WubDefaults.profileSpecPath("session/profiles/\(config.profile).yaml")
    let profText = try String(contentsOfFile: profPath, encoding: .utf8)
    let prof = try loadProfile(yaml: profText)

    let anchors = config.anchorsPack ?? prof.anchorsPack
    if anchors.contains("<pack_id>") {
      print("ERROR: anchors_pack in profile still contains <pack_id>. Pass --anchors-pack or edit the profile.")
      throw ExitCode(2)
    }

    let exe = CommandLine.arguments.first ?? "wub"
    var steps: [SessionReceiptV1.Step] = []
    var reasons: [String] = []

    func runStep(_ id: String, _ args: [String], notes: String? = nil) async -> Int {
      let cmd = ([exe] + args).joined(separator: " ")
      let code: Int32
      do { code = try await runProcess(exe: exe, args: args) }
      catch {
        reasons.append("\(id): \(error.localizedDescription)")
        steps.append(.init(id: id, command: cmd, exitCode: 999, notes: notes))
        return 999
      }
      steps.append(.init(id: id, command: cmd, exitCode: Int(code), notes: notes))
      if code != 0 { reasons.append("\(id): exit=\(code)") }
      return Int(code)
    }

    var voiceArgs = ["voice", "run",
                     "--script", prof.voiceScript,
                     "--abi", prof.voiceAbi,
                     "--anchors-pack", anchors,
                     "--regions", prof.regionsPath]
    if prof.voiceMacroOCR { voiceArgs += ["--macro-ocr", "--macro-region", prof.voiceMacroRegion] }
    if config.fix { voiceArgs += ["--fix"] }
    let voiceExit = await runStep("voice_run", voiceArgs, notes: "Voice compile handshake")

    let installExit = await runStep("rack_install",
                                    ["rack", "install", "--manifest", prof.rackManifest, "--macro-region", prof.rackMacroRegion, "--anchors-pack", anchors],
                                    notes: "Install racks by Browser search + double-click")

    let verifyExit = await runStep("rack_verify",
                                   ["rack", "verify", "--manifest", prof.rackManifest, "--macro-region", prof.rackMacroRegion, "--anchors-pack", anchors],
                                   notes: "Verify racks + macro labels")

    let status = (voiceExit == 0 && installExit == 0 && verifyExit == 0) ? "pass" : "fail"

    let receipt = SessionReceiptV1(
      schemaVersion: 1,
      runId: runId,
      timestamp: ISO8601DateFormatter().string(from: Date()),
      profileId: config.profile,
      status: status,
      artifacts: .init(
        sessionDir: "\(config.runsDir)/\(runId)",
        voiceReceipt: "\(config.runsDir)/\(runId)/voice_receipt.v1.json",
        rackInstallReceipt: "\(config.runsDir)/\(runId)/rack_install_receipt.v1.json",
        rackVerifyReceipt: "\(config.runsDir)/\(runId)/rack_receipt.v1.json",
        sweeperReport: "\(config.runsDir)/\(runId)/sweeper_report.v1.json",
        applyReceipt: "\(config.runsDir)/\(runId)/receipt.v1.json",
        applyTrace: "\(config.runsDir)/\(runId)/trace.v1.json"
      ),
      steps: steps,
      reasons: reasons
    )

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("session_receipt.v1.json"))

    return receipt
  }

  private struct Profile {
    let voiceScript: String
    let voiceAbi: String
    let voiceMacroOCR: Bool
    let voiceMacroRegion: String
    let rackManifest: String
    let rackMacroRegion: String
    let anchorsPack: String
    let regionsPath: String
  }

  private static func loadProfile(yaml: String) throws -> Profile {
    let loaded = try Yams.load(yaml: yaml)
    guard let root = loaded as? [String: Any] else {
      throw ValidationError("Invalid profile YAML")
    }

    func get(_ path: [String], _ defaultVal: Any? = nil) -> Any? {
      var cur: Any? = root
      for k in path {
        if let m = cur as? [String: Any] { cur = m[k] } else { return defaultVal }
      }
      return cur ?? defaultVal
    }

    guard let voiceScript = get(["voice", "script"]) as? String, !voiceScript.isEmpty else {
      throw ValidationError("Profile missing voice.script")
    }
    guard let voiceAbi = get(["voice", "abi"]) as? String, !voiceAbi.isEmpty else {
      throw ValidationError("Profile missing voice.abi")
    }
    let voiceMacroOCR = get(["voice", "macro_ocr"]) as? Bool ?? true
    let voiceMacroRegion = get(["voice", "macro_region"]) as? String ?? "rack.macros"

    let rackManifest = get(["racks", "manifest"]) as? String ?? WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json")
    let rackMacroRegion = get(["racks", "macro_region"]) as? String ?? "rack.macros"

    let anchorsPack = get(["automation", "anchors_pack"]) as? String ?? ""
    let regionsPath = get(["automation", "regions"]) as? String ?? "tools/automation/swift-cli/config/regions.v1.json"

    return Profile(voiceScript: voiceScript,
                   voiceAbi: voiceAbi,
                   voiceMacroOCR: voiceMacroOCR,
                   voiceMacroRegion: voiceMacroRegion,
                   rackManifest: rackManifest,
                   rackMacroRegion: rackMacroRegion,
                   anchorsPack: anchorsPack,
                   regionsPath: regionsPath)
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
