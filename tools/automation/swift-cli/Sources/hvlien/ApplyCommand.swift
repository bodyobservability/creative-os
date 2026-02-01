import Foundation
import ArgumentParser

struct Apply: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "apply",
    abstract: "Execute plan.v1.json using Teensy (default). Industrial-grade: anchor cancel + watchdog + ping/reconnect.")

  @OptionGroup var common: CommonOptions
  @Flag(name: .long, help: "Override station gating (dangerous).")
  var force: Bool = false
  @Option(name: .long) var plan: String
  @Option(name: .long) var teensy: String?
  @Flag(name: .long) var allowCgevent: Bool = false
  @Option(name: .long) var anchorsPack: String?
  @Option(name: .long) var watchdogMs: Int = 30000

  func run() async throws {
    try StationGate.enforceOrThrow(force: force, anchorsPackHint: anchorsPack ?? "", commandName: "apply")

    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()
    let runDir = ctx.runDir

    let planURL = URL(fileURLWithPath: plan)
    let planDoc = try JSONIO.load(PlanV1.self, from: planURL)
    let regionsDoc = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: common.regionsConfig))

    let actuatorInfo: ActuatorInfo
    let actuator: Actuator

    let teensyPath = self.teensy ?? TeensyDetect.autoDetectDevicePath()
    if let tp = teensyPath {
      do {
        actuator = try ReliableTeensyActuator(devicePath: tp)
        actuatorInfo = ActuatorInfo(type: "teensy", device: tp)
      } catch {
        if allowCgevent {
          actuator = CGEventActuator()
          actuatorInfo = ActuatorInfo(type: "cgevent", device: nil)
        } else {
          throw ValidationError("Teensy not available. Provide --teensy or use --allow-cgevent.")
        }
      }
    } else {
      if allowCgevent {
        actuator = CGEventActuator()
        actuatorInfo = ActuatorInfo(type: "cgevent", device: nil)
      } else {
        throw ValidationError("No Teensy detected. Provide --teensy or use --allow-cgevent.")
      }
    }

    let ev = common.evidence.lowercased()
    let evOpts: ApplyRunner.EvidenceOptions = {
      switch ev {
      case "none": return .init(writeOnSuccess: false, writeOnFailure: false, maxOcrLines: 250)
      case "all": return .init(writeOnSuccess: true, writeOnFailure: true, maxOcrLines: 250)
      default: return .init(writeOnSuccess: false, writeOnFailure: true, maxOcrLines: 250)
      }
    }()

    let traceURL = runDir.appendingPathComponent("trace.v1.json")
    let traceWriter = TraceWriter(runId: ctx.runId, outURL: traceURL)
    let receiptURL = runDir.appendingPathComponent("receipt.v1.json")
    let receiptWriter = ReceiptWriter(runId: ctx.runId, planPath: planURL.path, actuator: actuatorInfo, outURL: receiptURL)

    let capture = FrameCapture()
    // Preflight (minimal) can be run outside if already installed; we rely on production-grade preflight zip for that.
    let runner = ApplyRunner(capture: capture, regions: regionsDoc, actuator: actuator)
    runner.traceWriter = traceWriter
    runner.receiptWriter = receiptWriter
    runner.evidenceOptions = evOpts
    runner.runDir = runDir
    runner.anchorsPackPath = anchorsPack
    runner.watchdogOpMs = watchdogMs

    let report = try await runner.run(plan: planDoc, runDir: runDir)

    let finalStatus = report.prompts.isEmpty ? "success" : "failed"
    receiptWriter.finalize(status: finalStatus)
    receiptWriter.flush()
    traceWriter.flush()

    ConsolePrinter.printReportSummary(report)
    if finalStatus != "success" { throw ExitCode(1) }
  }
}
