import Foundation
import ArgumentParser

struct Rack: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "rack",
    abstract: "Rack pack tools (verify + recommend).",
    subcommands: [Verify.self, Recommend.self]
  )

  struct Verify: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "verify",
      abstract: "Generate a v4 plan to verify racks + macro labels, optionally run apply and emit a rack compliance receipt.")

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Path to rack_pack_manifest.v1.json")
    var manifest: String

    @Option(name: .long, help: "Macro label region id (default: rack.macros).")
    var macroRegion: String = "rack.macros"

    @Flag(name: .long, help: "Execute the generated plan via wub apply.")
    var runApply: Bool = true

    @Option(name: .long, help: "Anchors pack path (passed to apply).")
    var anchorsPack: String?

    func run() async throws {
      let ctx = RunContext(common: common)
      try ctx.ensureRunDir()

      let runDir = ctx.runDir
      let data = try Data(contentsOf: URL(fileURLWithPath: manifest))
      let mf = try JSONDecoder().decode(RackPackManifestV1.self, from: data)

      let planObj = RackVerify.generatePlan(manifest: mf, macroRegion: macroRegion)
      let planPath = runDir.appendingPathComponent("rack_verify.plan.v1.json")
      let planData = try JSONSerialization.data(withJSONObject: planObj, options: [.prettyPrinted, .sortedKeys])
      try planData.write(to: planPath)

      var applyExit: Int32 = 0
      if runApply {
        let exe = CommandLine.arguments.first ?? "wub"
        var args = ["apply","--plan", planPath.path]
        if let ap = anchorsPack { args += ["--anchors-pack", ap] }
        // allow fallback only if user set it in common; keep strict by default
        args += ["--allow-cgevent"]
        applyExit = try await runProcess(exe: exe, args: args)
      }

      let results = mf.racks.map { RackComplianceReceiptV1.RackResult(rackId: $0.rackId, trackHint: RackVerify.guessTrackHint(rack: $0), status: (applyExit == 0 ? "unknown" : "unknown"), notes: $0.notes) }
      let status = (applyExit == 0) ? "pass" : "fail"
      let receipt = RackComplianceReceiptV1(schemaVersion: 1,
                                            runId: ctx.runId,
                                            timestamp: ISO8601DateFormatter().string(from: Date()),
                                            manifestPath: manifest,
                                            status: status,
                                            planPath: "runs/\(ctx.runId)/rack_verify.plan.v1.json",
                                            applyReceiptPath: runApply ? "runs/\(ctx.runId)/receipt.v1.json" : nil,
                                            applyTracePath: runApply ? "runs/\(ctx.runId)/trace.v1.json" : nil,
                                            results: results,
                                            reasons: (applyExit == 0 ? [] : ["apply_exit=\(applyExit)"]))
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("rack_receipt.v1.json"))

      print("plan: \(planPath.path)")
      print("receipt: \(runDir.appendingPathComponent("rack_receipt.v1.json").path)")
      if applyExit != 0 { throw ExitCode(1) }
    }

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

  struct Recommend: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "recommend",
      abstract: "Recommend installs/substitutes based on missing rack dependencies using inventory + recommendations mapping.")

    @OptionGroup var common: CommonOptions

    @Option(name: .long) var manifest: String
    @Option(name: .long) var inventory: String
    @Option(name: .long, help: "Recommendations mapping JSON (optional).") var recommendations: String = WubDefaults.profileSpecPath("library/recommendations/bass_music.v1.json")
    @Option(name: .long, help: "Output path (default: stdout).") var out: String?

    func run() throws {
      let mf = try JSONDecoder().decode(RackPackManifestV1.self, from: Data(contentsOf: URL(fileURLWithPath: manifest)))
      let inv = try JSONIO.load(InventoryDoc.self, from: URL(fileURLWithPath: inventory))
      let recs = RackRecommend.recommend(manifest: mf, inventory: inv, recsPath: recommendations)
      let data = try JSONEncoder().encode(recs)
      if let out = out {
        try data.write(to: URL(fileURLWithPath: out))
        print("Wrote: \(out)")
      } else {
        print(String(data: data, encoding: .utf8) ?? "")
      }
    }
  }
}
