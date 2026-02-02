import Foundation
import ArgumentParser
import Yams

struct SessionService {
  struct SessionProfileConfig {
    let voiceScript: String
    let voiceAbi: String
    let voiceMacroOCR: Bool
    let voiceMacroRegion: String
    let rackManifest: String
    let rackMacroRegion: String
    let anchorsPack: String
    let regionsPath: String
  }

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

    let prof = try loadProfileConfig(profile: config.profile, profilePath: config.profilePath)

    let anchors = config.anchorsPack ?? prof.anchorsPack
    if anchors.contains("<pack_id>") {
      print("ERROR: anchors_pack in profile still contains <pack_id>. Pass --anchors-pack or edit the profile.")
      throw ExitCode(2)
    }

    var steps: [SessionReceiptV1.Step] = []
    var reasons: [String] = []

    func recordStep(id: String, command: String, exitCode: Int, notes: String? = nil) {
      steps.append(.init(id: id, command: command, exitCode: exitCode, notes: notes))
      if exitCode != 0 { reasons.append("\(id): exit=\(exitCode)") }
    }

    var voiceReceiptPath: String?
    var rackInstallReceiptPath: String?
    var rackVerifyReceiptPath: String?
    var sweeperReport: String?
    var applyReceipt: String?
    var applyTrace: String?

    let voiceExit: Int
    do {
      let receipt = try await VoiceService.run(config: .init(script: prof.voiceScript,
                                                             abi: prof.voiceAbi,
                                                             anchorsPack: anchors,
                                                             regions: prof.regionsPath,
                                                             macroOcr: prof.voiceMacroOCR,
                                                             macroRegion: prof.voiceMacroRegion,
                                                             fix: config.fix,
                                                             runsDir: config.runsDir))
      voiceReceiptPath = "\(config.runsDir)/\(receipt.runId)/voice_receipt.v1.json"
      sweeperReport = receipt.artifacts.sweeperReport
      applyReceipt = receipt.artifacts.applyReceipt
      applyTrace = receipt.artifacts.applyTrace
      voiceExit = (receipt.status == "pass") ? 0 : 1
      if voiceExit != 0 { reasons.append("voice_run: status=\(receipt.status)") }
    } catch {
      reasons.append("voice_run: \(error.localizedDescription)")
      voiceExit = 999
    }
    recordStep(id: "voice_run", command: "service: voice.run", exitCode: voiceExit, notes: "Voice compile handshake")

    let installExit: Int
    do {
      let receipt = try await RackInstallService.install(config: .init(manifest: prof.rackManifest,
                                                                       macroRegion: prof.rackMacroRegion,
                                                                       anchorsPack: anchors,
                                                                       allowCgevent: false,
                                                                       runsDir: config.runsDir))
      rackInstallReceiptPath = "\(config.runsDir)/\(receipt.runId)/rack_install_receipt.v1.json"
      installExit = (receipt.status == "pass") ? 0 : 1
      if installExit != 0 { reasons.append("rack_install: status=\(receipt.status)") }
    } catch {
      reasons.append("rack_install: \(error.localizedDescription)")
      installExit = 999
    }
    recordStep(id: "rack_install", command: "service: rack.install", exitCode: installExit, notes: "Install racks by Browser search + double-click")

    let verifyExit: Int
    do {
      let receipt = try await RackVerifyService.verify(config: .init(manifest: prof.rackManifest,
                                                                     macroRegion: prof.rackMacroRegion,
                                                                     runApply: true,
                                                                     anchorsPack: anchors,
                                                                     runsDir: config.runsDir))
      rackVerifyReceiptPath = "\(config.runsDir)/\(receipt.runId)/rack_receipt.v1.json"
      verifyExit = (receipt.status == "pass") ? 0 : 1
      if verifyExit != 0 { reasons.append("rack_verify: status=\(receipt.status)") }
    } catch {
      reasons.append("rack_verify: \(error.localizedDescription)")
      verifyExit = 999
    }
    recordStep(id: "rack_verify", command: "service: rack.verify", exitCode: verifyExit, notes: "Verify racks + macro labels")

    let status = (voiceExit == 0 && installExit == 0 && verifyExit == 0) ? "pass" : "fail"

    let receipt = SessionReceiptV1(
      schemaVersion: 1,
      runId: runId,
      timestamp: ISO8601DateFormatter().string(from: Date()),
      profileId: config.profile,
      status: status,
      artifacts: .init(
        sessionDir: "\(config.runsDir)/\(runId)",
        voiceReceipt: voiceReceiptPath,
        rackInstallReceipt: rackInstallReceiptPath,
        rackVerifyReceipt: rackVerifyReceiptPath,
        sweeperReport: sweeperReport,
        applyReceipt: applyReceipt,
        applyTrace: applyTrace
      ),
      steps: steps,
      reasons: reasons
    )

    try JSONIO.save(receipt, to: runDir.appendingPathComponent("session_receipt.v1.json"))

    return receipt
  }

  static func loadProfileConfig(profile: String, profilePath: String?) throws -> SessionProfileConfig {
    let profPath = profilePath ?? WubDefaults.profileSpecPath("session/profiles/\(profile).yaml")
    let profText = try String(contentsOfFile: profPath, encoding: .utf8)
    return try parseProfile(yaml: profText)
  }

  private static func parseProfile(yaml: String) throws -> SessionProfileConfig {
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

    return SessionProfileConfig(voiceScript: voiceScript,
                                voiceAbi: voiceAbi,
                                voiceMacroOCR: voiceMacroOCR,
                                voiceMacroRegion: voiceMacroRegion,
                                rackManifest: rackManifest,
                                rackMacroRegion: rackMacroRegion,
                                anchorsPack: anchorsPack,
                                regionsPath: regionsPath)
  }
}
