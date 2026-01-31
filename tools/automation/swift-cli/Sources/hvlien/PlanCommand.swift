import Foundation
import ArgumentParser

struct Plan: ParsableCommand {
  static let configuration = CommandConfiguration(commandName: "plan", abstract: "Generate plan.v1.json from spec + resolve_report.json")

  @OptionGroup var common: CommonOptions

  @Option(name: .long, help: "Path to YAML spec.")
  var spec: String

  @Option(name: .long, help: "Path to resolve_report.json.")
  var resolve: String

  @Option(name: .long, help: "Output plan path. Defaults to runs/<run_id>/plan.v1.json.")
  var out: String?

  func run() throws {
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()

    let outURL = out.map { URL(fileURLWithPath: $0) } ?? ctx.runDir.appendingPathComponent("plan.v1.json")
    let regions = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: common.regionsConfig))

    try PlanGenerator.generate(
      specPath: spec,
      resolveReportURL: URL(fileURLWithPath: resolve),
      outPlanURL: outURL,
      regions: regions
    )

    print("Run dir: \(ctx.runDir.path)")
    print("Wrote plan: \(outURL.path)")
  }
}
