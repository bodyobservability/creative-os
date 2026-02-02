import Foundation

struct SubMonoService {
  struct Config {
    let input: String
    let thresholds: String
    let out: String?
    let rackId: String?
    let profileId: String?
    let runsDir: String
  }

  static func run(config: Config) throws -> (receipt: SubMonoSafetyReceiptV1, outPath: String) {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let (bands, th) = SubMonoAnalyze.loadThresholds(path: config.thresholds.isEmpty ? nil : config.thresholds)
    let subBand = bands["sub"] ?? [20,120]

    let url = URL(fileURLWithPath: config.input)
    let (sr, dur, subMid, subSide) = try SubMonoAnalyze.analyze(url: url, subBand: subBand)
    let metrics = SubMonoAnalyze.computeMetrics(sr: sr, dur: dur, subMid: subMid, subSide: subSide)
    let (status, reasons, thMap) = SubMonoAnalyze.classify(metrics: metrics, th: th)

    let receipt = SubMonoSafetyReceiptV1(schemaVersion: 1,
                                         runId: runId,
                                         timestamp: ISO8601DateFormatter().string(from: Date()),
                                         inputAudio: config.input,
                                         rackId: config.rackId,
                                         profileId: config.profileId,
                                         status: status,
                                         bandsHz: ["sub": subBand, "low": bands["low"] ?? [120,250]],
                                         metrics: metrics,
                                         thresholds: thMap,
                                         reasons: reasons)

    let outPath = config.out ?? runDir.appendingPathComponent("sub_mono_safety_receipt.v1.json").path
    try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))

    return (receipt, outPath)
  }
}

struct TransientLowbandService {
  struct Config {
    let input: String
    let thresholds: String
    let out: String?
    let rackId: String?
    let profileId: String?
    let runsDir: String
  }

  static func run(config: Config) throws -> (receipt: TransientLowbandReceiptV1, outPath: String) {
    let runId = RunContext.makeRunId()
    let runDir = URL(fileURLWithPath: config.runsDir).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let (bands, th) = TransientLowbandAnalyze.load(path: config.thresholds.isEmpty ? nil : config.thresholds)
    let url = URL(fileURLWithPath: config.input)
    let (sr, dur, low, sub) = try TransientLowbandAnalyze.analyze(url: url, bands: bands)
    let metrics = TransientLowbandAnalyze.metrics(sr: sr, dur: dur, low: low, sub: sub)
    let (status, reasons, thMap) = TransientLowbandAnalyze.classify(m: metrics, th: th)

    let receipt = TransientLowbandReceiptV1(schemaVersion: 1,
                                            runId: runId,
                                            timestamp: ISO8601DateFormatter().string(from: Date()),
                                            inputAudio: config.input,
                                            rackId: config.rackId,
                                            profileId: config.profileId,
                                            status: status,
                                            bandsHz: bands.mapValues { $0 },
                                            metrics: metrics,
                                            thresholds: thMap,
                                            reasons: reasons)

    let outPath = config.out ?? runDir.appendingPathComponent("transient_lowband_receipt.v1.json").path
    try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))

    return (receipt, outPath)
  }
}
