import Foundation
import ArgumentParser

struct SubMonoCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sub-mono",
    abstract: "Analyze sub-band mono safety (20-120 Hz) and emit a sub-mono safety receipt."
  )

  @Option(name: .long, help: "Input audio file path (wav/aiff).")
  var input: String

  @Option(name: .long, help: "Thresholds JSON path (optional).")
  var thresholds: String = "specs/sonic/thresholds/sub_mono_safety_defaults.v1.json"

  @Option(name: .long, help: "Output receipt path (default: runs/<run_id>/sub_mono_safety_receipt.v1.json).")
  var out: String?

  @Option(name: .long) var rackId: String?
  @Option(name: .long) var profileId: String?

  func run() throws {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let (bands, th) = SubMonoAnalyze.loadThresholds(path: thresholds.isEmpty ? nil : thresholds)
    let subBand = bands["sub"] ?? [20,120]

    let url = URL(fileURLWithPath: input)
    let (sr, dur, subMid, subSide) = try SubMonoAnalyze.analyze(url: url, subBand: subBand)
    let metrics = SubMonoAnalyze.computeMetrics(sr: sr, dur: dur, subMid: subMid, subSide: subSide)
    let (status, reasons, thMap) = SubMonoAnalyze.classify(metrics: metrics, th: th)

    let receipt = SubMonoSafetyReceiptV1(schemaVersion: 1,
      runId: runId,
      timestamp: ISO8601DateFormatter().string(from: Date()),
      inputAudio: input,
      rackId: rackId,
      profileId: profileId,
      status: status,
      bandsHz: ["sub": subBand, "low": bands["low"] ?? [120,250]],
      metrics: metrics,
      thresholds: thMap,
      reasons: reasons
    )

    let outPath = out ?? runDir.appendingPathComponent("sub_mono_safety_receipt.v1.json").path
    try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))

    print("status: \(status)")
    if !reasons.isEmpty { print("reasons:"); for r in reasons { print(" - \(r)") } }
    print("receipt: \(outPath)")
    if status == "fail" { throw ExitCode(1) }
  }
}
