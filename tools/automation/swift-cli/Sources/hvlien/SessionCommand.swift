import Foundation
import ArgumentParser
import Yams

struct Session: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "session",
    abstract: "Session compiler (v5+v6 orchestration).",
    subcommands: [Compile.self]
  )

  struct Compile: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "compile",
      abstract: "Compile a session end-to-end: voice handshake, rack install, rack verify."
    )

    @Option(name: .long, help: "Profile id (e.g. bass_v1).")
    var profile: String

    @Option(name: .long, help: "Profile path override (optional).")
    var profilePath: String?

    @Option(name: .long, help: "Anchors pack path override (optional).")
    var anchorsPack: String?

    @Flag(name: .long, help: "Run doctor --fix during voice handshake.")
    var fix: Bool = false

    func run() async throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

      let profPath = profilePath ?? "specs/session/profiles/\(profile).yaml"
      let profText = try String(contentsOfFile: profPath, encoding: .utf8)
      let prof = try loadProfile(yaml: profText)

      let anchors = anchorsPack ?? prof.anchorsPack
      if anchors.contains("<pack_id>") {
        print("ERROR: anchors_pack in profile still contains <pack_id>. Pass --anchors-pack or edit the profile.")
        throw ExitCode(2)
      }

      let exe = CommandLine.arguments.first ?? "hvlien"
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

      // 1) v5 voice handshake (prints card, waits, runs doctor+apply verify)
      var voiceArgs = ["voice","run",
                       "--script", prof.voiceScript,
                       "--abi", prof.voiceAbi,
                       "--anchors-pack", anchors,
                       "--regions", prof.regionsPath]
      if prof.voiceMacroOCR { voiceArgs += ["--macro-ocr", "--macro-region", prof.voiceMacroRegion] }
      if fix { voiceArgs += ["--fix"] }
      let voiceExit = await runStep("voice_run", voiceArgs, notes: "Voice compile handshake")

      // 2) v6 rack install (strict by default; allow fallback only via apply flags in your stack)
      let installExit = await runStep("rack_install",
                                      ["rack","install","--manifest", prof.rackManifest, "--macro-region", prof.rackMacroRegion, "--anchors-pack", anchors],
                                      notes: "Install racks by Browser search + double-click")

      // 3) v6 rack verify
      let verifyExit = await runStep("rack_verify",
                                     ["rack","verify","--manifest", prof.rackManifest, "--macro-region", prof.rackMacroRegion, "--anchors-pack", anchors],
                                     notes: "Verify racks + macro labels")

      let status = (voiceExit == 0 && installExit == 0 && verifyExit == 0) ? "pass" : "fail"

      // Expected artifact locations (best-effort; these commands write into their own runs/<id> directories,
      // but when invoked from this process they will also write into the current runId directory if they use RunContext.
      // We record the primary session run dir anyway.
      let receipt = SessionReceiptV1(
        schemaVersion: 1,
        runId: runId,
        timestamp: ISO8601DateFormatter().string(from: Date()),
        profileId: profile,
        status: status,
        artifacts: .init(
          sessionDir: "runs/\(runId)",
          voiceReceipt: "runs/\(runId)/voice_receipt.v1.json",
          rackInstallReceipt: "runs/\(runId)/rack_install_receipt.v1.json",
          rackVerifyReceipt: "runs/\(runId)/rack_receipt.v1.json",
          doctorReport: "runs/\(runId)/doctor_report.v1.json",
          applyReceipt: "runs/\(runId)/receipt.v1.json",
          applyTrace: "runs/\(runId)/trace.v1.json"
        ),
        steps: steps,
        reasons: reasons
      )

      try JSONIO.save(receipt, to: runDir.appendingPathComponent("session_receipt.v1.json"))
      print("\nsession_receipt: runs/\(runId)/session_receipt.v1.json")
      if status != "pass" { throw ExitCode(1) }
    }

    // MARK: profile parsing

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

    private func loadProfile(yaml: String) throws -> Profile {
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

      let voiceScript = get(["voice","script"]) as? String ?? "specs/voice/scripts/bass_template_build.v1.yaml"
      let voiceAbi = get(["voice","abi"]) as? String ?? "specs/voice/abi/hvlien_macro_abi.v1.yaml"
      let voiceMacroOCR = get(["voice","macro_ocr"]) as? Bool ?? true
      let voiceMacroRegion = get(["voice","macro_region"]) as? String ?? "rack.macros"

      let rackManifest = get(["racks","manifest"]) as? String ?? "specs/library/racks/rack_pack_manifest.v1.json"
      let rackMacroRegion = get(["racks","macro_region"]) as? String ?? "rack.macros"

      let anchorsPack = get(["automation","anchors_pack"]) as? String ?? ""
      let regionsPath = get(["automation","regions"]) as? String ?? "tools/automation/swift-cli/config/regions.v1.json"

      return Profile(voiceScript: voiceScript,
                     voiceAbi: voiceAbi,
                     voiceMacroOCR: voiceMacroOCR,
                     voiceMacroRegion: voiceMacroRegion,
                     rackManifest: rackManifest,
                     rackMacroRegion: rackMacroRegion,
                     anchorsPack: anchorsPack,
                     regionsPath: regionsPath)
    }

    // MARK: process runner

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
