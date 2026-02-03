import Foundation
import ArgumentParser

struct ApplyService {
  struct Config {
    let planPath: String
    let anchorsPack: String?
    let allowCgevent: Bool
    let force: Bool
    let runsDir: String
    let regionsConfig: String
    let evidence: String
    let watchdogMs: Int
  }

  struct Result {
    let runId: String
    let status: String
    let receiptPath: String
    let tracePath: String
  }

  static func run(config: Config) async throws -> Result {
    try StationGate.enforceOrThrow(force: config.force,
                                   anchorsPackHint: config.anchorsPack ?? "",
                                   commandName: "apply")

    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: runDir.appendingPathComponent("evidence", isDirectory: true), withIntermediateDirectories: true)

    let planURL = URL(fileURLWithPath: config.planPath)
    let planDoc = try JSONIO.load(PlanV1.self, from: planURL)
    let regionsDoc = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: config.regionsConfig))

    let actuatorInfo: ActuatorInfo
    let actuator: Actuator

    let teensyPath = TeensyDetect.autoDetectDevicePath()
    if let tp = teensyPath {
      do {
        actuator = try ReliableTeensyActuator(devicePath: tp)
        actuatorInfo = ActuatorInfo(type: "teensy", device: tp)
      } catch {
        if config.allowCgevent {
          actuator = CGEventActuator()
          actuatorInfo = ActuatorInfo(type: "cgevent", device: nil)
        } else {
          throw ValidationError("Teensy not available. Provide --allow-cgevent.")
        }
      }
    } else {
      if config.allowCgevent {
        actuator = CGEventActuator()
        actuatorInfo = ActuatorInfo(type: "cgevent", device: nil)
      } else {
        throw ValidationError("No Teensy detected. Use --allow-cgevent.")
      }
    }

    let ev = config.evidence.lowercased()
    let evOpts: ApplyRunner.EvidenceOptions = {
      switch ev {
      case "none": return .init(writeOnSuccess: false, writeOnFailure: false, maxOcrLines: 250)
      case "all": return .init(writeOnSuccess: true, writeOnFailure: true, maxOcrLines: 250)
      default: return .init(writeOnSuccess: false, writeOnFailure: true, maxOcrLines: 250)
      }
    }()

    let traceURL = runDir.appendingPathComponent("trace.v1.json")
    let traceWriter = TraceWriter(runId: runId, outURL: traceURL)
    let receiptURL = runDir.appendingPathComponent("receipt.v1.json")
    let receiptWriter = ReceiptWriter(runId: runId, planPath: planURL.path, actuator: actuatorInfo, outURL: receiptURL)

    let capture = FrameCapture()
    let runner = ApplyRunner(capture: capture, regions: regionsDoc, actuator: actuator)
    runner.traceWriter = traceWriter
    runner.receiptWriter = receiptWriter
    runner.evidenceOptions = evOpts
    runner.runDir = runDir
    runner.anchorsPackPath = config.anchorsPack
    runner.watchdogOpMs = config.watchdogMs

    let report = try await runner.run(plan: planDoc, runDir: runDir)

    let finalStatus = report.prompts.isEmpty ? "success" : "failed"
    receiptWriter.finalize(status: finalStatus)
    receiptWriter.flush()
    traceWriter.flush()

    return Result(runId: runId,
                  status: finalStatus,
                  receiptPath: "\(config.runsDir)/\(runId)/receipt.v1.json",
                  tracePath: "\(config.runsDir)/\(runId)/trace.v1.json")
  }
}
