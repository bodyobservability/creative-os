import Foundation
import ArgumentParser

extension Rack {
  struct Install: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install",
      abstract: "Instantiate racks from the manifest into target tracks by searching Ableton Browser and inserting. Emits rack_install_receipt.")

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Path to rack_pack_manifest.v1.json")
    var manifest: String

    @Option(name: .long, help: "Macro label region id (default: rack.macros)")
    var macroRegion: String = "rack.macros"

    @Option(name: .long, help: "Anchors pack path (passed to apply)")
    var anchorsPack: String?

    @Flag(name: .long, help: "Allow CGEvent fallback during apply (otherwise rely on Teensy default).")
    var allowCgevent: Bool = false

    func run() async throws {
      let ctx = RunContext(common: common)
      try ctx.ensureRunDir()
      let runDir = ctx.runDir

      let mf = try JSONDecoder().decode(RackPackManifestV1.self, from: Data(contentsOf: URL(fileURLWithPath: manifest)))

      // Generate plan in run folder
      let planObj = RackInstall.generateInstallPlan(manifest: mf, macroRegion: macroRegion)
      let planPath = runDir.appendingPathComponent("rack_install.plan.v1.json")
      let planData = try JSONSerialization.data(withJSONObject: planObj, options: [.prettyPrinted, .sortedKeys])
      try planData.write(to: planPath)

      // Execute apply
      let exe = CommandLine.arguments.first ?? "hvlien"
      var args = ["apply","--plan", planPath.path]
      if let ap = anchorsPack { args += ["--anchors-pack", ap] }
      if allowCgevent { args += ["--allow-cgevent"] }
      let applyExit = try await runProcess(exe: exe, args: args)

      let installed = mf.racks.map { RackInstallReceiptV1.InstalledRack(rackId: $0.rackId,
                                                                       targetTrack: $0.targetTrack ?? RackVerify.guessTrackHint(rack: $0) ?? "Track",
                                                                       decision: (applyExit == 0 ? "attempted" : "failed"),
                                                                       notes: $0.notes) }
      let status = (applyExit == 0) ? "pass" : "fail"
      let receipt = RackInstallReceiptV1(schemaVersion: 1,
                                         runId: ctx.runId,
                                         timestamp: ISO8601DateFormatter().string(from: Date()),
                                         manifestPath: manifest,
                                         status: status,
                                         planPath: "runs/\(ctx.runId)/rack_install.plan.v1.json",
                                         applyReceiptPath: "runs/\(ctx.runId)/receipt.v1.json",
                                         applyTracePath: "runs/\(ctx.runId)/trace.v1.json",
                                         installed: installed,
                                         reasons: (applyExit == 0 ? [] : ["apply_exit=\(applyExit)"]))
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("rack_install_receipt.v1.json"))

      print("plan: \(planPath.path)")
      print("receipt: \(runDir.appendingPathComponent("rack_install_receipt.v1.json").path)")
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
}
