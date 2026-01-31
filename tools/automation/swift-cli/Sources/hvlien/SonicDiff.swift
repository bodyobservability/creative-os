import Foundation

enum SonicDiff {
  struct SweepReceipt: Decodable {
    struct Summary: Decodable {
      let worstTruePeakDbfs: Double
      let worstRmsDbfs: Double
      let worstDcOffsetAbs: Double
      let minStereoCorrelation: Double?
      let suggestedSafeMaxPosition: Double
      enum CodingKeys: String, CodingKey {
        case worstTruePeakDbfs = "worst_true_peak_dbfs"
        case worstRmsDbfs = "worst_rms_dbfs"
        case worstDcOffsetAbs = "worst_dc_offset_abs"
        case minStereoCorrelation = "min_stereo_correlation"
        case suggestedSafeMaxPosition = "suggested_safe_max_position"
      }
    }
    let macro: String
    let summary: Summary
  }

  static func diff(baselinePath: String, currentPath: String) throws -> SonicDiffReceiptV1 {
    let runId = RunContext.makeRunId()
    let ts = ISO8601DateFormatter().string(from: Date())

    let b = try JSONDecoder().decode(SweepReceipt.self, from: Data(contentsOf: URL(fileURLWithPath: baselinePath)))
    let c = try JSONDecoder().decode(SweepReceipt.self, from: Data(contentsOf: URL(fileURLWithPath: currentPath)))

    // deltas: current - baseline
    let dtp = c.summary.worstTruePeakDbfs - b.summary.worstTruePeakDbfs
    let drms = c.summary.worstRmsDbfs - b.summary.worstRmsDbfs
    let ddc = c.summary.worstDcOffsetAbs - b.summary.worstDcOffsetAbs
    let dcorr: Double? = {
      if let bc = b.summary.minStereoCorrelation, let cc = c.summary.minStereoCorrelation { return cc - bc }
      return nil
    }()
    let dsafe = c.summary.suggestedSafeMaxPosition - b.summary.suggestedSafeMaxPosition

    var status = "pass"
    var reasons: [String] = []

    // Heuristics: failing regressions
    if dtp > 0.5 { status = "warn"; reasons.append("true_peak worse by \(fmt(dtp)) dB") }
    if drms > 1.0 { status = "warn"; reasons.append("rms worse by \(fmt(drms)) dB") }
    if dsafe < -0.10 { status = "warn"; reasons.append("safe max shrank by \(fmt(dsafe))") }

    let deltas = SonicDiffDeltasV1(worstTruePeakDb: dtp, worstRmsDb: drms, worstDcOffsetAbs: ddc, minStereoCorr: dcorr, safeMaxPositionDelta: dsafe)
    return SonicDiffReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, baseline: baselinePath, current: currentPath, status: status, deltas: deltas, reasons: reasons)
  }

  static func fmt(_ x: Double) -> String { String(format: "%.2f", x) }
}
