import Foundation

enum SonicSweep {

  struct Thresholds {
    var maxTruePeakDbfs: Double = -1.0
    var maxDcOffsetAbs: Double = 0.02
    var minStereoCorrelation: Double = -0.2
    var maxRmsDbfsWarn: Double = -10.0
    var maxRmsDbfsFail: Double = -6.0
  }

  static func loadThresholds(path: String?) -> Thresholds {
    var th = Thresholds()
    guard let p = path, FileManager.default.fileExists(atPath: p),
          let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let t = obj["thresholds"] as? [String: Any] else { return th }
    if let v = t["max_true_peak_dbfs"] as? Double { th.maxTruePeakDbfs = v }
    if let v = t["max_dc_offset_abs"] as? Double { th.maxDcOffsetAbs = v }
    if let v = t["min_stereo_correlation"] as? Double { th.minStereoCorrelation = v }
    if let v = t["max_rms_dbfs_warn"] as? Double { th.maxRmsDbfsWarn = v }
    if let v = t["max_rms_dbfs_fail"] as? Double { th.maxRmsDbfsFail = v }
    return th
  }

  static func classifySample(metrics: SonicMetricsV1, thresholds: Thresholds) -> (status: String, reasons: [String]) {
    var status = "pass"
    var reasons: [String] = []

    if metrics.truePeakDbfs > thresholds.maxTruePeakDbfs {
      status = "fail"
      reasons.append("true_peak_dbfs \(fmt(metrics.truePeakDbfs)) > \(fmt(thresholds.maxTruePeakDbfs))")
    }
    if abs(metrics.dcOffset) > thresholds.maxDcOffsetAbs {
      status = maxStatus(status, "warn")
      reasons.append("dc_offset \(fmt(metrics.dcOffset)) exceeds \(fmt(thresholds.maxDcOffsetAbs))")
    }
    if let c = metrics.stereoCorrelation, c < thresholds.minStereoCorrelation {
      status = maxStatus(status, "warn")
      reasons.append("stereo_correlation \(fmt(c)) < \(fmt(thresholds.minStereoCorrelation))")
    }
    if metrics.rmsDbfs > thresholds.maxRmsDbfsFail {
      status = "fail"
      reasons.append("rms_dbfs \(fmt(metrics.rmsDbfs)) > fail \(fmt(thresholds.maxRmsDbfsFail))")
    } else if metrics.rmsDbfs > thresholds.maxRmsDbfsWarn {
      status = maxStatus(status, "warn")
      reasons.append("rms_dbfs \(fmt(metrics.rmsDbfs)) > warn \(fmt(thresholds.maxRmsDbfsWarn))")
    }
    return (status, reasons)
  }

  static func aggregate(macro: String,
                        samples: [SonicSweepSampleV1],
                        thresholds: Thresholds) -> (status: String, summary: SonicSweepSummaryV1, suggestedMaxPos: Double) {
    let worstTP = samples.map { $0.metrics.truePeakDbfs }.max() ?? -999
    let worstRms = samples.map { $0.metrics.rmsDbfs }.max() ?? -999
    let worstDc = samples.map { abs($0.metrics.dcOffset) }.max() ?? 0
    let minCorr = samples.compactMap { $0.metrics.stereoCorrelation }.min()

    // suggested safe max position = highest position that is not fail
    let sorted = samples.sorted { $0.position < $1.position }
    var safeMax = sorted.first?.position ?? 0.0
    for s in sorted {
      if s.status != "fail" { safeMax = s.position }
      else { break }
    }

    // overall status: fail if any fail, warn if any warn, else pass
    var overall = "pass"
    if samples.contains(where: { $0.status == "fail" }) { overall = "fail" }
    else if samples.contains(where: { $0.status == "warn" }) { overall = "warn" }

    let summary = SonicSweepSummaryV1(
      worstTruePeakDbfs: worstTP,
      worstRmsDbfs: worstRms,
      worstDcOffsetAbs: worstDc,
      minStereoCorrelation: minCorr,
      suggestedSafeMaxPosition: safeMax
    )
    return (overall, summary, safeMax)
  }

  static func fmt(_ x: Double) -> String { String(format: "%.2f", x) }
  static func maxStatus(_ a: String, _ b: String) -> String {
    let rank: [String:Int] = ["pass":0,"warn":1,"fail":2]
    return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b
  }
}
