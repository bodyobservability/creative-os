import Foundation

struct ReleaseAgent: CreativeOS.Agent {
  let id: String = "release"
  let config: ReleaseService.PromoteConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = "wub release promote-profile --profile \(config.profile) --rack-id \(config.rackId) --macro \(config.macro) --baseline \(config.baseline) --current-sweep \(config.currentSweep)"
    let cfg = CreativeOSActionCatalog.releasePromoteProfileConfig(profile: config.profile,
                                                                  rackId: config.rackId,
                                                                  macro: config.macro,
                                                                  baseline: config.baseline,
                                                                  currentSweep: config.currentSweep,
                                                                  out: config.out,
                                                                  rackManifest: config.rackManifest,
                                                                  runsDir: config.runsDir)
    p.register(id: "release_promote_profile") {
      [CreativeOS.PlanStep(id: "release_promote_profile",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [
                             cfg,
                             CreativeOS.Effect(id: "release_promote_profile", kind: .process, target: cmd, description: "Promote profile")
                           ],
                           idempotent: true,
                           manualReason: "release_promote_required",
                           actionRef: CreativeOSActionCatalog.releasePromoteProfile.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
