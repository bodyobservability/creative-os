import Foundation

struct VoiceRackSessionAgent: CreativeOS.Agent {
  let id: String = "voice_rack_session"
  let config: VoiceRackSessionConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let anchorsPack = config.anchorsPack.flatMap { $0.isEmpty ? nil : $0 }
    let anchorsFlag = anchorsPack ?? ""
    let apArgs = anchorsFlag.isEmpty ? "" : " --anchors-pack \(anchorsFlag)"
    let macroArgs = config.macroRegion.isEmpty ? "" : " --macro-region \(config.macroRegion)"
    let cgArg = config.allowCgevent ? " --allow-cgevent" : ""
    let fixArg = config.fix ? " --fix" : ""

    let voiceCmd = "wub voice run" + apArgs + macroArgs + fixArg
    let rackInstallCmd = "wub rack install" + apArgs + macroArgs + cgArg
    let rackVerifyCmd = "wub rack verify" + apArgs + macroArgs
    let sessionCmd = "wub session compile --profile \(config.sessionProfile)" + (anchorsFlag.isEmpty ? "" : " --anchors-pack \(anchorsFlag)")
    let vrsCfg = CreativeOSActionCatalog.voiceRackSessionConfig(sessionProfile: config.sessionProfile,
                                                                sessionProfilePath: WubDefaults.profileSpecPath("session/profiles/\(config.sessionProfile).yaml"),
                                                                anchorsPack: anchorsPack,
                                                                macroRegion: config.macroRegion,
                                                                allowCgevent: config.allowCgevent,
                                                                fix: config.fix)
    let sessionCfg = CreativeOSActionCatalog.sessionCompileConfig(profile: config.sessionProfile,
                                                                  anchorsPack: anchorsPack,
                                                                  fix: config.fix)

    p.register(id: "voice_run") {
      [CreativeOS.PlanStep(id: "voice_run",
                           agent: id,
                           type: .automated,
                           description: "Run: \(voiceCmd)",
                           effects: [
                             vrsCfg,
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
                             vrsCfg,
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
                             vrsCfg,
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
