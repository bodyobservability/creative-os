import Foundation
import ArgumentParser

struct A0: AsyncParsableCommand {
  @OptionGroup var common: CommonOptions
  @Option(name: .long) var spec: String

  func run() async throws {
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()

    let invURL = ctx.runDir.appendingPathComponent("inventory.v1.json")
    let ctrlURL = ctx.runDir.appendingPathComponent("controllers_inventory.v1.json")
    let repURL = ctx.runDir.appendingPathComponent("resolve_report.json")

    // A0 capture is intentionally manual-assisted in v2 for safety.
    // If you already have an inventory, you can skip A0 and use `resolve`.
    try await CapturePhase.run(runId: ctx.runId, outInventoryURL: invURL)

    let ctrlDoc = buildControllersInventoryDoc(ableton: common.ableton)
    try JSONIO.save(ctrlDoc, to: ctrlURL)

    let report = try ResolvePhase.runResolve(specPath: spec,
                                            inventoryURL: invURL,
                                            controllersURL: ctrlURL,
                                            substitutionsPath: common.substitutions,
                                            recommendationsPath: common.recommendations,
                                            packSignaturesPath: common.packSignatures,
                                            preferredFormats: ctx.preferredFormats)
    try JSONIO.save(report, to: repURL)

    ConsolePrinter.printReportSummary(report)
    if common.interactive && !report.prompts.isEmpty {
      try InteractivePromptLoop.run(prompts: report.prompts, runDir: ctx.runDir)
    }
    let code = reportExitCode(report)
    if code != 0 { throw ExitCode(code) }
  }
}

struct Resolve: ParsableCommand {
  @OptionGroup var common: CommonOptions
  @Option(name: .long) var spec: String
  @Option(name: .long) var inventory: String
  @Option(name: .long) var controllers: String

  func run() throws {
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()
    let repURL = ctx.runDir.appendingPathComponent("resolve_report.json")

    let report = try ResolvePhase.runResolve(specPath: spec,
                                            inventoryURL: URL(fileURLWithPath: inventory),
                                            controllersURL: URL(fileURLWithPath: controllers),
                                            substitutionsPath: common.substitutions,
                                            recommendationsPath: common.recommendations,
                                            packSignaturesPath: common.packSignatures,
                                            preferredFormats: ctx.preferredFormats)
    try JSONIO.save(report, to: repURL)
    ConsolePrinter.printReportSummary(report)
    if common.interactive && !report.prompts.isEmpty {
      try InteractivePromptLoop.run(prompts: report.prompts, runDir: ctx.runDir)
    }
    let code = reportExitCode(report)
    if code != 0 { throw ExitCode(code) }
  }
}
