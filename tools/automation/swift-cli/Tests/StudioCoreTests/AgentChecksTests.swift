import XCTest
@testable import StudioCore

final class AgentChecksTests: XCTestCase {
  private func runChecks(_ agent: CreativeOS.Agent) throws -> [CreativeOS.CheckResult] {
    var registry = CreativeOS.CheckRegistry()
    agent.registerChecks(&registry)
    return try registry.entries.map { try $0.run() }
  }

  private func touch(_ path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    _ = FileManager.default.createFile(atPath: path, contents: Data(), attributes: nil)
  }

  func testKeyAgentsRegisterChecks() throws {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tempDir) }

    let anchorsPack = tempDir.appendingPathComponent("anchors.pack").path
    let artifactIndex = tempDir.appendingPathComponent("artifact_index.v1.json").path
    let receiptIndex = tempDir.appendingPathComponent("receipt_index.v1.json").path
    let regionsConfig = tempDir.appendingPathComponent("regions.v1.json").path
    let rackManifest = tempDir.appendingPathComponent("rack_manifest.v1.json").path
    let vrlMapping = tempDir.appendingPathComponent("vrl_mapping.v1.yaml").path
    let voiceScript = tempDir.appendingPathComponent("voice_script.v1.yaml").path
    let voiceAbi = tempDir.appendingPathComponent("voice_abi.v1.yaml").path
    let voiceRegions = tempDir.appendingPathComponent("voice_regions.v1.json").path
    let currentSweep = tempDir.appendingPathComponent("current_sweep.v1.json").path

    for path in [anchorsPack, artifactIndex, receiptIndex, regionsConfig, rackManifest, vrlMapping, voiceScript, voiceAbi, voiceRegions, currentSweep] {
      try touch(path)
    }

    let ready = ReadyAgent(config: .init(anchorsPackHint: anchorsPack,
                                         artifactIndex: artifactIndex,
                                         runDir: nil,
                                         writeReport: true))

    let drift = DriftAgent(checkConfig: .init(artifactIndex: artifactIndex,
                                              receiptIndex: receiptIndex,
                                              anchorsPackHint: anchorsPack,
                                              out: nil,
                                              format: "human",
                                              groupByFix: true,
                                              onlyFail: false),
                           fixConfig: .init(force: false,
                                            artifactIndex: artifactIndex,
                                            receiptIndex: receiptIndex,
                                            anchorsPackHint: anchorsPack,
                                            yes: false,
                                            dryRun: true,
                                            out: nil,
                                            runsDir: "runs"))

    let station = StationAgent(config: .init(format: "human",
                                             out: nil,
                                             noWriteReport: true,
                                             anchorsPackHint: anchorsPack,
                                             runsDir: "runs"))

    let assets = AssetsAgent(config: .init(anchorsPack: anchorsPack,
                                           overwrite: false,
                                           nonInteractive: true,
                                           preflight: true,
                                           runsDir: "runs",
                                           regionsConfig: regionsConfig,
                                           racksOut: tempDir.appendingPathComponent("racks_out").path,
                                           performanceOut: tempDir.appendingPathComponent("performance_out").path,
                                           baysSpec: tempDir.appendingPathComponent("bays_spec.v1.yaml").path,
                                           serumOut: tempDir.appendingPathComponent("serum_out.fxp").path,
                                           extrasSpec: tempDir.appendingPathComponent("extras_spec.v1.yaml").path,
                                           postcheck: true,
                                           rackVerifyManifest: rackManifest,
                                           vrlMapping: vrlMapping,
                                           force: false))

    let voice = VoiceRackSessionAgent(voiceConfig: .init(script: voiceScript,
                                                         abi: voiceAbi,
                                                         anchorsPack: anchorsPack,
                                                         regions: voiceRegions,
                                                         macroOcr: true,
                                                         macroRegion: "rack.macros",
                                                         fix: false,
                                                         runsDir: "runs"),
                                      rackInstallConfig: .init(manifest: rackManifest,
                                                               macroRegion: "rack.macros",
                                                               anchorsPack: anchorsPack,
                                                               allowCgevent: false,
                                                               runsDir: "runs"),
                                      rackVerifyConfig: .init(manifest: rackManifest,
                                                              macroRegion: "rack.macros",
                                                              runApply: true,
                                                              anchorsPack: anchorsPack,
                                                              runsDir: "runs"),
                                      sessionConfig: .init(profile: "hvlien",
                                                           profilePath: nil,
                                                           anchorsPack: anchorsPack,
                                                           fix: false,
                                                           runsDir: "runs"))

    let index = IndexAgent(config: .init(repoVersion: "v1.0.0",
                                         outDir: tempDir.path,
                                         runsDir: "runs"))

    let release = ReleaseAgent(config: .init(profile: tempDir.appendingPathComponent("profile.v1.yaml").path,
                                             out: nil,
                                             rackId: "rack_a",
                                             macro: "macro_1",
                                             baseline: "baseline",
                                             currentSweep: currentSweep,
                                             rackManifest: rackManifest,
                                             runsDir: "runs"))

    let repair = RepairAgent(config: .init(force: false,
                                           anchorsPackHint: anchorsPack,
                                           yes: false,
                                           overwrite: true,
                                           runsDir: "runs"))

    let agents: [CreativeOS.Agent] = [ready, drift, station, assets, voice, index, release, repair]
    for agent in agents {
      let checks = try runChecks(agent)
      XCTAssertFalse(checks.isEmpty, "Expected checks for agent \(agent.id)")
      XCTAssertTrue(checks.allSatisfy { !$0.suggestedActions.isEmpty }, "Expected suggested actions for agent \(agent.id)")
    }
  }
}
