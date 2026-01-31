import Foundation
import ArgumentParser
import Yams

struct Release: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "release",
    abstract: "Release channel governance (v8.2).",
    subcommands: [PromoteProfile.self]
  )

  struct PromoteProfile: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "promote-profile",
      abstract: "Promote a tuned profile from dev->release after passing certification gates."
    )

    @Option(name: .long, help: "Tuned profile YAML path (candidate).")
    var profile: String

    @Option(name: .long, help: "Release output path (default: specs/library/profiles/release/<name>.yaml).")
    var out: String?

    @Option(name: .long, help: "Rack id used for baseline certification.")
    var rackId: String

    @Option(name: .long, help: "Macro used for baseline certification (e.g. Width).")
    var macro: String

    @Option(name: .long, help: "Baseline sweep receipt path.")
    var baseline: String

    @Option(name: .long, help: "Current sweep receipt path (from latest calibration).")
    var currentSweep: String

    @Option(name: .long, help: "Rack manifest path (optional).")
    var rackManifest: String = "specs/library/racks/rack_pack_manifest.v1.json"

    func run() async throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

      let exe = CommandLine.arguments.first ?? "hvlien"
      var gates: [PromotionGateResult] = []
      var reasons: [String] = []

      // Gate 1: sonic certify
      let profileId = inferProfileId(from: profile)
      let certifyArgs = ["sonic","certify","--baseline", baseline, "--sweep", currentSweep, "--rack-id", rackId, "--profile-id", profileId, "--macro", macro]
      let certifyExit = await runProcess(exe: exe, args: certifyArgs)
      gates.append(.init(id: "sonic_certify", command: ([exe]+certifyArgs).joined(separator: " "), exitCode: Int(certifyExit)))
      if certifyExit != 0 { reasons.append("sonic_certify failed") }

      // Gate 2: rack verify (if manifest exists)
      if FileManager.default.fileExists(atPath: rackManifest) {
        let rvArgs = ["rack","verify","--manifest", rackManifest, "--macro-region", "rack.macros"]
        let rvExit = await runProcess(exe: exe, args: rvArgs)
        gates.append(.init(id: "rack_verify", command: ([exe]+rvArgs).joined(separator: " "), exitCode: Int(rvExit)))
        if rvExit != 0 { reasons.append("rack_verify failed") }
      } else {
        gates.append(.init(id: "rack_verify", command: "skipped (manifest missing)", exitCode: 0))
      }

      let status = reasons.isEmpty ? "pass" : "fail"
      let outPath = out ?? defaultReleasePath(for: profile)

      if status == "pass" {
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: (outPath as NSString).deletingLastPathComponent), withIntermediateDirectories: true)
        // Overwrite if exists
        if FileManager.default.fileExists(atPath: outPath) { try FileManager.default.removeItem(atPath: outPath) }
        try FileManager.default.copyItem(atPath: profile, toPath: outPath)
      }

      let receipt = ProfilePromotionReceiptV1(schemaVersion: 1,
                                              runId: runId,
                                              timestamp: ISO8601DateFormatter().string(from: Date()),
                                              profileIn: profile,
                                              profileOut: outPath,
                                              status: status,
                                              gates: gates,
                                              reasons: reasons)
      try JSONIO.save(receipt, to: runDir.appendingPathComponent("profile_promotion_receipt.v1.json"))

      print("receipt: runs/\(runId)/profile_promotion_receipt.v1.json")
      if status != "pass" { throw ExitCode(1) }
    }

    private func inferProfileId(from path: String) -> String {
      let u = URL(fileURLWithPath: path)
      return u.deletingPathExtension().lastPathComponent
    }

    private func defaultReleasePath(for profile: String) -> String {
      let u = URL(fileURLWithPath: profile)
      return "specs/library/profiles/release/\(u.lastPathComponent)"
    }

    private func runProcess(exe: String, args: [String]) async -> Int32 {
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
}
