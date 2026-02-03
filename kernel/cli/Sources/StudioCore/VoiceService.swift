import Foundation
import ArgumentParser

struct VoiceService {
  struct RunConfig {
    let script: String
    let abi: String
    let anchorsPack: String
    let regions: String
    let macroOcr: Bool
    let macroRegion: String
    let fix: Bool
    let runsDir: String
  }

  static func run(config: RunConfig) async throws -> VoiceReceiptV1 {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: runDir.appendingPathComponent("voice", isDirectory: true), withIntermediateDirectories: true)

    let cardPath = runDir.appendingPathComponent("voice/voice_card.md").path
    _ = try VoicePrint.renderMarkdown(scriptPath: config.script,
                                      anchorsPack: config.anchorsPack,
                                      displayProfile: nil,
                                      abletonVersion: nil,
                                      abletonTheme: nil,
                                      outPath: cardPath)

    let verifyPlanPath = runDir.appendingPathComponent("voice/verify_abi.plan.json").path
    try VoiceVerify.generatePlan(abiPath: config.abi,
                                 outPath: verifyPlanPath,
                                 includeMacroNameOCR: config.macroOcr,
                                 macroRegionId: config.macroRegion)

    print("\nVoice prompt card written to: \(cardPath)")
    print("Open it, run the voice compile script, then press Enter to continue. Type 'q' then Enter to abort.")
    let resp = readLine() ?? ""
    if resp.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "q" {
      let receipt = VoiceReceiptV1.failed(runId: runId,
                                          script: config.script,
                                          abi: config.abi,
                                          card: "\(config.runsDir)/\(runId)/voice/voice_card.md",
                                          verifyPlan: "\(config.runsDir)/\(runId)/voice/verify_abi.plan.json",
                                          sweeperReport: nil,
                                          applyReceipt: nil,
                                          applyTrace: nil,
                                          reasons: ["aborted_by_user"])
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("voice_receipt.v1.json"))
      throw ExitCode(3)
    }

    let exe = CommandLine.arguments.first ?? "wub"
    var sweeperArgs = ["sweep", "--anchors-pack", config.anchorsPack, "--modal-test", "detect", "--allow-ocr-fallback"]
    if config.fix { sweeperArgs.insert("--fix", at: 1) }
    sweeperArgs += ["--require-controller", "MPK mini IV"]
    let sweeperExit = try await runProcess(exe: exe, args: sweeperArgs, cwd: FileManager.default.currentDirectoryPath)
    let sweeperReport = "\(config.runsDir)/\(runId)/sweeper_report.v1.json"

    let applyArgs = ["apply", "--plan", verifyPlanPath, "--anchors-pack", config.anchorsPack, "--allow-cgevent"]
    let applyExit = try await runProcess(exe: exe, args: applyArgs, cwd: FileManager.default.currentDirectoryPath)
    let applyReceipt = "\(config.runsDir)/\(runId)/receipt.v1.json"
    let applyTrace = "\(config.runsDir)/\(runId)/trace.v1.json"

    let status: String = (sweeperExit == 0 && applyExit == 0) ? "pass" : "fail"
    let compliance = VoiceCompliance(structural: (applyExit == 0) ? "pass" : "fail",
                                     macroNames: config.macroOcr ? ((applyExit == 0) ? "pass" : "fail") : "skip",
                                     ranges: "skip")
    let receipt = VoiceReceiptV1(schemaVersion: 1,
                                 runId: runId,
                                 timestamp: ISO8601DateFormatter().string(from: Date()),
                                 script: config.script,
                                 abi: config.abi,
                                 status: status,
                                 compliance: compliance,
                                 artifacts: VoiceArtifacts(promptCard: "\(config.runsDir)/\(runId)/voice/voice_card.md",
                                                           verifyPlan: "\(config.runsDir)/\(runId)/voice/verify_abi.plan.json",
                                                           sweeperReport: sweeperReport,
                                                           applyReceipt: applyReceipt,
                                                           applyTrace: applyTrace),
                                 reasons: (status == "pass") ? [] : ["sweeper_exit=\(sweeperExit)", "apply_exit=\(applyExit)"])
    try JSONIO.save(receipt, to: runDir.appendingPathComponent("voice_receipt.v1.json"))

    return receipt
  }

  private static func runProcess(exe: String, args: [String], cwd: String) async throws -> Int32 {
    return try await withCheckedThrowingContinuation { cont in
      let p = Process()
      p.executableURL = URL(fileURLWithPath: exe)
      p.arguments = args
      p.currentDirectoryURL = URL(fileURLWithPath: cwd)
      p.standardOutput = FileHandle.standardOutput
      p.standardError = FileHandle.standardError
      p.terminationHandler = { proc in
        cont.resume(returning: proc.terminationStatus)
      }
      do { try p.run() } catch { cont.resume(throwing: error) }
    }
  }
}
