import Foundation
import ArgumentParser

struct Voice: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "voice",
    abstract: "Voice layer utilities (print prompt cards, generate verification plans, run handshake).",
    subcommands: [Print.self, Verify.self, Run.self],
    defaultSubcommand: Print.self
  )

  struct Print: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "print", abstract: "Render a voice script as a one-page Markdown prompt card.")

    @Option(name: .long, help: "Path to voice script YAML.")
    var script: String

    @Option(name: .long, help: "Anchors pack path to embed in instructions.")
    var anchorsPack: String?

    @Option(name: .long, help: "Output Markdown path (optional).")
    var out: String?

    @Option(name: .long, help: "Display profile label (optional).")
    var display: String?

    @Option(name: .long, help: "Ableton version label (optional).")
    var ableton: String?

    @Option(name: .long, help: "Ableton theme label (optional).")
    var theme: String?

    func run() throws {
      let md = try VoicePrint.renderMarkdown(scriptPath: script,
                                            anchorsPack: anchorsPack,
                                            displayProfile: display,
                                            abletonVersion: ableton,
                                            abletonTheme: theme,
                                            outPath: out)
      if out == nil { print(md) }
    }
  }

  struct Verify: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify", abstract: "Generate a v4 verification plan from the macro ABI.")

    @Option(name: .long, help: "Path to macro ABI YAML.")
    var abi: String

    @Option(name: .long, help: "Output plan JSON path.")
    var out: String

    @Option(name: .long, help: "Enable macro-name OCR checks (requires regions 'rack.macros').")
    var macroOcr: Bool = false

    @Option(name: .long, help: "Macro label region id (default: rack.macros).")
    var macroRegion: String = "rack.macros"

    func run() throws {
      try VoiceVerify.generatePlan(abiPath: abi, outPath: out, includeMacroNameOCR: macroOcr, macroRegionId: macroRegion)
      print("Wrote plan: \(out)")
    }
  }

  struct Run: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "run", abstract: "Voice+v4 handshake: print card, wait for human compile, then doctor + apply verify, emit voice_receipt.v1.json")

    @Option(name: .long, help: "Path to voice script YAML.")
    var script: String

    @Option(name: .long, help: "Path to macro ABI YAML.")
    var abi: String

    @Option(name: .long, help: "Anchors pack path (for doctor/apply).")
    var anchorsPack: String

    @Option(name: .long, help: "Regions config path.")
    var regions: String = "tools/automation/swift-cli/config/regions.v1.json"

    @Option(name: .long, help: "Enable macro-name OCR checks (requires regions 'rack.macros').")
    var macroOcr: Bool = false

    @Option(name: .long, help: "Macro label region id (default: rack.macros).")
    var macroRegion: String = "rack.macros"

    @Option(name: .long, help: "Run doctor with --fix first.")
    var fix: Bool = false

    func run() async throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
      try FileManager.default.createDirectory(at: runDir.appendingPathComponent("voice", isDirectory: true), withIntermediateDirectories: true)

      // 1) Write prompt card
      let cardPath = runDir.appendingPathComponent("voice/voice_card.md").path
      _ = try VoicePrint.renderMarkdown(scriptPath: script,
                                        anchorsPack: anchorsPack,
                                        displayProfile: nil,
                                        abletonVersion: nil,
                                        abletonTheme: nil,
                                        outPath: cardPath)

      // 2) Generate verification plan into run folder
      let verifyPlanPath = runDir.appendingPathComponent("voice/verify_abi.plan.json").path
      try VoiceVerify.generatePlan(abiPath: abi, outPath: verifyPlanPath, includeMacroNameOCR: macroOcr, macroRegionId: macroRegion)

      // 3) Prompt human to run voice compile
      print("\nVoice prompt card written to: \(cardPath)")
      print("Open it, run the voice compile script, then press Enter to continue. Type 'q' then Enter to abort.")
      let resp = readLine() ?? ""
      if resp.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) == "q" {
        let receipt = VoiceReceiptV1.failed(runId: runId, script: script, abi: abi, card: "runs/\(runId)/voice/voice_card.md",
                                            verifyPlan: "runs/\(runId)/voice/verify_abi.plan.json",
                                            doctorReport: nil, applyReceipt: nil, applyTrace: nil,
                                            reasons: ["aborted_by_user"])
        try JSONIO.save(receipt, to: runDir.appendingPathComponent("voice_receipt.v1.json"))
        throw ExitCode(3)
      }

      // 4) Run doctor (spawn self)
      let exe = CommandLine.arguments.first ?? "hvlien"
      var doctorArgs = ["doctor", "--anchors-pack", anchorsPack, "--modal-test", "detect", "--allow-ocr-fallback"]
      if fix { doctorArgs.insert("--fix", at: 1) }
      doctorArgs += ["--require-controller", "MPK mini IV"]
      let doctorExit = try await runProcess(exe: exe, args: doctorArgs, cwd: FileManager.default.currentDirectoryPath)
      let doctorReport = "runs/\(runId)/doctor_report.v1.json"

      // 5) Run apply verification plan
      let applyArgs = ["apply", "--plan", verifyPlanPath, "--anchors-pack", anchorsPack, "--allow-cgevent"]
      let applyExit = try await runProcess(exe: exe, args: applyArgs, cwd: FileManager.default.currentDirectoryPath)
      let applyReceipt = "runs/\(runId)/receipt.v1.json"
      let applyTrace = "runs/\(runId)/trace.v1.json"

      // 6) Emit voice receipt
      let status: String = (doctorExit == 0 && applyExit == 0) ? "pass" : "fail"
      let compliance = VoiceCompliance(structural: (applyExit == 0) ? "pass" : "fail",
                                       macroNames: macroOcr ? ((applyExit == 0) ? "pass" : "fail") : "skip",
                                       ranges: "skip")
      let receipt = VoiceReceiptV1(schemaVersion: 1,
                                   runId: runId,
                                   timestamp: ISO8601DateFormatter().string(from: Date()),
                                   script: script,
                                   abi: abi,
                                   status: status,
                                   compliance: compliance,
                                   artifacts: VoiceArtifacts(promptCard: "runs/\(runId)/voice/voice_card.md",
                                                            verifyPlan: "runs/\(runId)/voice/verify_abi.plan.json",
                                                            doctorReport: doctorReport,
                                                            applyReceipt: applyReceipt,
                                                            applyTrace: applyTrace),
                                   reasons: (status == "pass") ? [] : ["doctor_exit=\(doctorExit)", "apply_exit=\(applyExit)"])
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("voice_receipt.v1.json"))
      print("\nvoice_receipt: runs/\(runId)/voice_receipt.v1.json")
      if status != "pass" { throw ExitCode(1) }
    }

    private func runProcess(exe: String, args: [String], cwd: String) async throws -> Int32 {
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
}
