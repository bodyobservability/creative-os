import Foundation

struct VoiceRackSessionAgent: CreativeOS.Agent {
  let id: String = "voice_rack_session"
  let voiceConfig: VoiceService.RunConfig
  let rackInstallConfig: RackInstallService.Config
  let rackVerifyConfig: RackVerifyService.Config
  let sessionConfig: SessionService.Config

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
    r.register(id: "voice_rack_session_inputs") {
      var observed: [String: CreativeOS.JSONValue] = [
        "voice_regions_exists": .bool(FileManager.default.fileExists(atPath: voiceConfig.regions)),
        "rack_install_manifest_exists": .bool(FileManager.default.fileExists(atPath: rackInstallConfig.manifest)),
        "rack_verify_manifest_exists": .bool(FileManager.default.fileExists(atPath: rackVerifyConfig.manifest))
      ]
      var expected: [String: CreativeOS.JSONValue] = [
        "voice_regions_exists": .bool(true),
        "rack_install_manifest_exists": .bool(true),
        "rack_verify_manifest_exists": .bool(true)
      ]
      let anchorsPack = voiceConfig.anchorsPack
      if !anchorsPack.isEmpty {
        let anchorsOk = FileManager.default.fileExists(atPath: anchorsPack)
        observed["anchors_pack_exists"] = .bool(anchorsOk)
        expected["anchors_pack_exists"] = .bool(true)
      }
      let ok = !observed.values.contains { value in
        if case .bool(false) = value { return true }
        return false
      }
      return CreativeOS.CheckResult(id: "voice_rack_session_inputs",
                                    agent: id,
                                    severity: ok ? .pass : .warn,
                                    category: .filesystem,
                                    observed: .object(observed),
                                    expected: .object(expected),
                                    evidence: [],
                                    suggestedActions: [
                                      CreativeOSActionCatalog.voiceRun.actionRef,
                                      CreativeOSActionCatalog.rackInstall.actionRef,
                                      CreativeOSActionCatalog.rackVerify.actionRef,
                                      CreativeOSActionCatalog.sessionCompile.actionRef
                                    ])
    }
  }

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let anchorsPack = voiceConfig.anchorsPack.isEmpty ? nil : voiceConfig.anchorsPack
    let anchorsFlag = anchorsPack ?? ""
    let apArgs = anchorsFlag.isEmpty ? "" : " --anchors-pack \(anchorsFlag)"
    let macroArgs = voiceConfig.macroRegion.isEmpty ? "" : " --macro-region \(voiceConfig.macroRegion)"
    let cgArg = rackInstallConfig.allowCgevent ? " --allow-cgevent" : ""
    let fixArg = voiceConfig.fix ? " --fix" : ""

    let voiceCmd = "wub voice run" + apArgs + macroArgs + fixArg
    let rackInstallCmd = "wub rack install" + apArgs + macroArgs + cgArg
    let rackVerifyCmd = "wub rack verify" + apArgs + macroArgs
    let sessionCmd = "wub session compile --profile \(sessionConfig.profile)" + (anchorsFlag.isEmpty ? "" : " --anchors-pack \(anchorsFlag)")
    let voiceCfg = CreativeOSActionCatalog.voiceRunConfig(config: voiceConfig)
    let rackInstallCfg = CreativeOSActionCatalog.rackInstallConfig(config: rackInstallConfig)
    let rackVerifyCfg = CreativeOSActionCatalog.rackVerifyConfig(config: rackVerifyConfig)
    let sessionCfg = CreativeOSActionCatalog.sessionCompileConfig(profile: sessionConfig.profile,
                                                                  profilePath: sessionConfig.profilePath,
                                                                  anchorsPack: anchorsPack,
                                                                  fix: sessionConfig.fix)

    p.register(id: "voice_run") {
      [CreativeOS.PlanStep(id: "voice_run",
                           agent: id,
                           type: .automated,
                           description: "Run: \(voiceCmd)",
                           effects: [
                             voiceCfg,
                             CreativeOS.Effect(id: "voice_run", kind: .process, target: voiceCmd, description: "Run voice handshake")
                           ],
                           idempotent: true,
                           manualReason: "voice_run_required",
                           actionRef: CreativeOSActionCatalog.voiceRun.actionRef)]
    }
    p.register(id: "rack_install") {
      [CreativeOS.PlanStep(id: "rack_install",
                           agent: id,
                           type: .automated,
                           description: "Run: \(rackInstallCmd)",
                           effects: [
                             rackInstallCfg,
                             CreativeOS.Effect(id: "rack_install", kind: .process, target: rackInstallCmd, description: "Install racks")
                           ],
                           idempotent: true,
                           manualReason: "rack_install_required",
                           actionRef: CreativeOSActionCatalog.rackInstall.actionRef)]
    }
    p.register(id: "rack_verify") {
      [CreativeOS.PlanStep(id: "rack_verify",
                           agent: id,
                           type: .automated,
                           description: "Run: \(rackVerifyCmd)",
                           effects: [
                             rackVerifyCfg,
                             CreativeOS.Effect(id: "rack_verify", kind: .process, target: rackVerifyCmd, description: "Verify racks")
                           ],
                           idempotent: true,
                           manualReason: "rack_verify_required",
                           actionRef: CreativeOSActionCatalog.rackVerify.actionRef)]
    }
    p.register(id: "session_compile") {
      [CreativeOS.PlanStep(id: "session_compile",
                           agent: id,
                           type: .automated,
                           description: "Run: \(sessionCmd)",
                           effects: [sessionCfg, CreativeOS.Effect(id: "session_compile", kind: .process, target: sessionCmd, description: "Compile session")],
                           idempotent: true,
                           manualReason: "session_compile_required",
                           actionRef: CreativeOSActionCatalog.sessionCompile.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
