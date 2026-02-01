import Foundation
import ArgumentParser

struct TransientLowbandCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "transient-low",
    abstract: "Analyze low-band transient/headroom safety and emit a receipt."
  )

  @Option(name: .long) var input: String
  @Option(name: .long) var thresholds: String = WubDefaults.profileSpecPath("sonic/thresholds/transient_lowband_defaults.v1.json")
  @Option(name: .long) var out: String?
  @Option(name: .long) var rackId: String?
  @Option(name: .long) var profileId: String?

  func run() throws {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let (bands, th) = TransientLowbandAnalyze.load(path: thresholds.isEmpty ? nil : thresholds)
    let url = URL(fileURLWithPath: input)
    let (sr, dur, low, sub) = try TransientLowbandAnalyze.analyze(url: url, bands: bands)
    let metrics = TransientLowbandAnalyze.metrics(sr: sr, dur: dur, low: low, sub: sub)
    let (status, reasons, thMap) = TransientLowbandAnalyze.classify(m: metrics, th: th)

    let receipt = TransientLowbandReceiptV1(schemaVersion: 1,
      runId: runId,
      timestamp: ISO8601DateFormatter().string(from: Date()),
      inputAudio: input,
      rackId: rackId,
      profileId: profileId,
      status: status,
      bandsHz: bands.mapValues { $0 },
      metrics: metrics,
      thresholds: thMap,
      reasons: reasons)

    let outPath = out ?? runDir.appendingPathComponent("transient_lowband_receipt.v1.json").path
    try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))

    print("status: \(status)")
    if !reasons.isEmpty { print("reasons:"); for r in reasons { print(" - \(r)") } }
    print("receipt: \(outPath)")
    if status == "fail" { throw ExitCode(1) }
  }
}
