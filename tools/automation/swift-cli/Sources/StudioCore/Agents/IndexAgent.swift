import Foundation

struct IndexAgent: CreativeOS.Agent {
  let id: String = "index"
  let config: IndexConfig

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = "wub index build --repo-version \(config.repoVersion) --out-dir \(config.outDir) --runs-dir \(config.runsDir)"
    let cfg = CreativeOSActionCatalog.indexBuildConfig(repoVersion: config.repoVersion,
                                                       outDir: config.outDir,
                                                       runsDir: config.runsDir)
    p.register(id: "index_build") {
      [CreativeOS.PlanStep(id: "index_build",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [
                             cfg,
                             CreativeOS.Effect(id: "index_build", kind: .process, target: cmd, description: "Build indexes")
                           ],
                           idempotent: true,
                           manualReason: "index_build_required",
                           actionRef: CreativeOSActionCatalog.indexBuild.actionRef)]
    }
    p.register(id: "index_status") {
      let statusCmd = "wub index status"
      return [CreativeOS.PlanStep(id: "index_status",
                                  agent: id,
                                  type: .manualRequired,
                                  description: "Run: \(statusCmd)",
                                  effects: [CreativeOS.Effect(id: "index_status", kind: .process, target: statusCmd, description: "Check index status")],
                                  idempotent: true,
                                  manualReason: "index_status_required")]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }
}
