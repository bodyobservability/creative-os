import Foundation

struct SweeperAgent: CreativeOS.Agent {
  let id: String = "sweeper"
  let config: SweeperService.Config

  func registerChecks(_ r: inout CreativeOS.CheckRegistry) {}

  func registerPlans(_ p: inout CreativeOS.PlanRegistry) {
    let cmd = buildCommand()
    let cfg = CreativeOSActionCatalog.sweeperConfig(anchorsPack: config.anchorsPack,
                                                    modalTest: config.modalTest,
                                                    requiredControllers: config.requiredControllers,
                                                    allowOcrFallback: config.allowOcrFallback,
                                                    fix: config.fix)
    p.register(id: "sweep_maintenance") {
      [CreativeOS.PlanStep(id: "sweep_maintenance",
                           agent: id,
                           type: .automated,
                           description: "Run: \(cmd)",
                           effects: [
                             cfg,
                             CreativeOS.Effect(id: "sweep_command", kind: .process, target: cmd, description: "Run maintenance sweep")
                           ],
                           idempotent: true,
                           manualReason: "sweep_required",
                           actionRef: CreativeOSActionCatalog.sweeperRun.actionRef)]
    }
  }

  func observeState() throws -> CreativeOS.ObservedStateSlice {
    CreativeOS.ObservedStateSlice(agentId: id, data: nil, raw: nil)
  }

  private func buildCommand() -> String {
    var args: [String] = ["wub", "sweep"]
    if let anchorsPack = config.anchorsPack, !anchorsPack.isEmpty {
      args += ["--anchors-pack", anchorsPack]
    }
    if !config.modalTest.isEmpty {
      args += ["--modal-test", config.modalTest]
    }
    if config.allowOcrFallback {
      args.append("--allow-ocr-fallback")
    }
    if config.fix {
      args.append("--fix")
    }
    for controller in config.requiredControllers {
      args += ["--require-controller", controller]
    }
    return args.joined(separator: " ")
  }
}
