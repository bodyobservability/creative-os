import Foundation
import AVFoundation

enum SubMonoAnalyze {

  struct Thresholds {
    var maxSubSideRatio: Double = 0.12
    var minSubCorr: Double = 0.85
    var maxSubDcOffsetAbs: Double = 0.01
    var maxSubTruePeakDbfs: Double = -1.0
  }

  static func loadThresholds(path: String?) -> (bands: [String:[Double]], th: Thresholds) {
    var th = Thresholds()
    var bands: [String:[Double]] = ["sub":[20,120], "low":[120,250]]
    guard let p = path, FileManager.default.fileExists(atPath: p),
          let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return (bands, th)
    }
    if let b = obj["bands_hz"] as? [String: Any] {
      if let sub = b["sub"] as? [Double], sub.count == 2 { bands["sub"] = sub }
      if let low = b["low"] as? [Double], low.count == 2 { bands["low"] = low }
    }
    if let t = obj["thresholds"] as? [String: Any] {
      if let v = t["max_sub_side_ratio"] as? Double { th.maxSubSideRatio = v }
      if let v = t["min_sub_corr"] as? Double { th.minSubCorr = v }
      if let v = t["max_sub_dc_offset_abs"] as? Double { th.maxSubDcOffsetAbs = v }
      if let v = t["max_sub_true_peak_dbfs"] as? Double { th.maxSubTruePeakDbfs = v }
    }
    return (bands, th)
  }

  static func analyze(url: URL, subBand: [Double]) throws -> (sr: Double, dur: Double, mid: [Double], side: [Double]) {
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    let sr = format.sampleRate
    let ch = Int(format.channelCount)
    let frames = AVAudioFrameCount(file.length)

    guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
      throw NSError(domain: "SubMonoAnalyze", code: 1, userInfo: [NSLocalizedDescriptionKey: "buffer alloc failed"])
    }
    try file.read(into: buf)
    guard let fdata = buf.floatChannelData else {
      throw NSError(domain: "SubMonoAnalyze", code: 2, userInfo: [NSLocalizedDescriptionKey: "expected float pcm"])
    }
    let n = Int(buf.frameLength)
    if n == 0 { throw NSError(domain: "SubMonoAnalyze", code: 3, userInfo: [NSLocalizedDescriptionKey: "empty audio"])    }

    // Build mono or stereo mid/side
    var L = [Double](repeating: 0, count: n)
    var R = [Double](repeating: 0, count: n)
    for i in 0..<n {
      L[i] = Double(fdata[0][i])
      R[i] = (ch >= 2) ? Double(fdata[1][i]) : L[i]
    }
    var mid = [Double](repeating: 0, count: n)
    var side = [Double](repeating: 0, count: n)
    for i in 0..<n {
      mid[i] = 0.5 * (L[i] + R[i])
      side[i] = 0.5 * (L[i] - R[i])
    }

    // Band-pass filter mid+side to sub band
    let sub = bandpassButterworth2(samples: mid, sr: sr, lowHz: subBand[0], highHz: subBand[1])
    let subSide = bandpassButterworth2(samples: side, sr: sr, lowHz: subBand[0], highHz: subBand[1])
    let dur = Double(n) / sr
    return (sr, dur, sub, subSide)
  }

  static func computeMetrics(sr: Double, dur: Double, subMid: [Double], subSide: [Double]) -> SubMonoMetricsV1 {
    _ = Double(min(subMid.count, subSide.count))
    let midRms = rms(subMid)
    let sideRms = rms(subSide)
    let ratio = (midRms > 1e-12) ? (sideRms / midRms) : 0.0
    let corr = correlation(subMid, subSide: subSide) // correlation between L/R reconstructed? We'll approximate via mid vs side -> derive L/R corr proxy later.
    let dc = mean(subMid)
    let truePeak = linToDbfs(estimateTruePeakAbs(samples: subMid, oversample: 4))

    return SubMonoMetricsV1(sampleRateHz: sr, durationS: dur, subMidRms: midRms, subSideRms: sideRms, subSideRatio: ratio,
                           subCorr: corr, subDcOffset: dc, subTruePeakDbfs: truePeak)
  }

  static func classify(metrics: SubMonoMetricsV1, th: Thresholds) -> (status: String, reasons: [String], thMap: [String: Double]) {
    var status = "pass"
    var reasons: [String] = []
    let thMap: [String: Double] = [
      "max_sub_side_ratio": th.maxSubSideRatio,
      "min_sub_corr": th.minSubCorr,
      "max_sub_dc_offset_abs": th.maxSubDcOffsetAbs,
      "max_sub_true_peak_dbfs": th.maxSubTruePeakDbfs
    ]

    if metrics.subSideRatio > th.maxSubSideRatio {
      status = "fail"
      reasons.append("sub_side_ratio \(fmt(metrics.subSideRatio)) > \(fmt(th.maxSubSideRatio))")
    }
    if metrics.subCorr < th.minSubCorr {
      status = maxStatus(status, "warn")
      reasons.append("sub_corr \(fmt(metrics.subCorr)) < \(fmt(th.minSubCorr))")
    }
    if abs(metrics.subDcOffset) > th.maxSubDcOffsetAbs {
      status = maxStatus(status, "warn")
      reasons.append("sub_dc_offset \(fmt(metrics.subDcOffset)) exceeds \(fmt(th.maxSubDcOffsetAbs))")
    }
    if metrics.subTruePeakDbfs > th.maxSubTruePeakDbfs {
      status = "fail"
      reasons.append("sub_true_peak_dbfs \(fmt(metrics.subTruePeakDbfs)) > \(fmt(th.maxSubTruePeakDbfs))")
    }
    return (status, reasons, thMap)
  }

  // -------- DSP helpers (simple biquad cascade) --------

  private static func bandpassButterworth2(samples: [Double], sr: Double, lowHz: Double, highHz: Double) -> [Double] {
    // 2nd order bandpass by cascading 1st order HP + 1st order LP (cheap, stable)
    let hp = onePoleHP(samples: samples, sr: sr, cutoff: lowHz)
    let lp = onePoleLP(samples: hp, sr: sr, cutoff: highHz)
    return lp
  }

  private static func onePoleLP(samples: [Double], sr: Double, cutoff: Double) -> [Double] {
    let x = exp(-2.0 * Double.pi * cutoff / sr)
    var y = [Double](repeating: 0, count: samples.count)
    var prev = 0.0
    for i in 0..<samples.count {
      prev = (1 - x) * samples[i] + x * prev
      y[i] = prev
    }
    return y
  }

  private static func onePoleHP(samples: [Double], sr: Double, cutoff: Double) -> [Double] {
    let x = exp(-2.0 * Double.pi * cutoff / sr)
    var y = [Double](repeating: 0, count: samples.count)
    var prevY = 0.0
    var prevX = 0.0
    for i in 0..<samples.count {
      let curX = samples[i]
      let curY = x * (prevY + curX - prevX)
      y[i] = curY
      prevY = curY
      prevX = curX
    }
    return y
  }

  private static func rms(_ a: [Double]) -> Double {
    var s = 0.0
    for v in a { s += v*v }
    return (s / Double(max(1,a.count))).squareRoot()
  }

  private static func mean(_ a: [Double]) -> Double {
    var s = 0.0
    for v in a { s += v }
    return s / Double(max(1,a.count))
  }

  private static func correlation(_ subMid: [Double], subSide: [Double]) -> Double {
    // Proxy: compute correlation of reconstructed L and R in sub band
    let n = min(subMid.count, subSide.count)
    var sumXY = 0.0, sumX2 = 0.0, sumY2 = 0.0
    for i in 0..<n {
      let L = subMid[i] + subSide[i]
      let R = subMid[i] - subSide[i]
      sumXY += L * R
      sumX2 += L * L
      sumY2 += R * R
    }
    let denom = (sumX2.squareRoot() * sumY2.squareRoot())
    return denom > 0 ? (sumXY / denom) : 1.0
  }

  private static func estimateTruePeakAbs(samples: [Double], oversample: Int) -> Double {
    if samples.count < 2 { return 0 }
    var tp = 0.0
    for i in 0..<(samples.count-1) {
      let a = samples[i], b = samples[i+1]
      for k in 0..<oversample {
        let t = Double(k) / Double(oversample)
        let y = a + (b - a) * t
        let ay = abs(y)
        if ay > tp { tp = ay }
      }
    }
    return tp
  }

  private static func linToDbfs(_ x: Double) -> Double {
    let v = max(x, 1e-12)
    return 20.0 * log10(v)
  }

  private static func maxStatus(_ a: String, _ b: String) -> String {
    let rank: [String:Int] = ["pass":0,"warn":1,"fail":2]
    return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b
  }
  private static func fmt(_ x: Double) -> String { String(format: "%.3f", x) }
}
