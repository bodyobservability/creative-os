import Foundation

struct ReleaseAgent: CreativeOS.Agent {
  let id: String = "release"
  let config: ReleaseService.PromoteConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {
    r.register(id: "release_inputs") {
      let manifestOk = FileManager.default.fileExists(atPath: config.rackManifest)
      let sweepOk = FileManager.default.fileExists(atPath: config.currentSweep)
      let observed: CreativeOS.JSONValue = .object([
        "rack_manifest_exists": .bool(manifestOk),
        "current_sweep_exists": .bool(sweepOk)
      ])
      let expected: CreativeOS.JSONValue = .object([
        "rack_manifest_exists": .bool(true),
        "current_sweep_exists": .bool(true)
      ])
      let ok = manifestOk && sweepOk
      return CreativeOS.CheckResult(id: "release_inputs",
                                    agent: id,
                                    severity: ok ? .pass : .warn,
                                    category: .filesystem,
                                    observed: observed,
                                    expected: expected,
                                    evidence: [],
                                    suggestedActions: [CreativeOSActionCatalog.releasePromoteProfile.actionRef])
    }
  }

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
