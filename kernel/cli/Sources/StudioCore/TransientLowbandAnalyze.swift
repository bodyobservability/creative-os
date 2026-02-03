import Foundation
import AVFoundation

enum TransientLowbandAnalyze {

  struct Thresholds {
    var minLowCrestDbWarn: Double = 6.0
    var minLowCrestDbFail: Double = 4.0
    var maxLowRmsDbfsWarn: Double = -10.0
    var maxLowRmsDbfsFail: Double = -6.0
    var maxSubTruePeakDbfs: Double = -1.0
  }

  static func load(path: String?) -> (bands: [String:[Double]], th: Thresholds) {
    var bands: [String:[Double]] = ["sub":[20,120], "low":[20,250]]
    var th = Thresholds()
    guard let p = path, FileManager.default.fileExists(atPath: p),
          let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return (bands, th) }
    if let b = obj["bands_hz"] as? [String: Any] {
      if let sub = b["sub"] as? [Double], sub.count == 2 { bands["sub"] = sub }
      if let low = b["low"] as? [Double], low.count == 2 { bands["low"] = low }
    }
    if let t = obj["thresholds"] as? [String: Any] {
      if let v = t["min_low_crest_db_warn"] as? Double { th.minLowCrestDbWarn = v }
      if let v = t["min_low_crest_db_fail"] as? Double { th.minLowCrestDbFail = v }
      if let v = t["max_low_rms_dbfs_warn"] as? Double { th.maxLowRmsDbfsWarn = v }
      if let v = t["max_low_rms_dbfs_fail"] as? Double { th.maxLowRmsDbfsFail = v }
      if let v = t["max_sub_true_peak_dbfs"] as? Double { th.maxSubTruePeakDbfs = v }
    }
    return (bands, th)
  }

  static func analyze(url: URL, bands: [String:[Double]]) throws -> (sr: Double, dur: Double, low: [Double], sub: [Double]) {
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    let sr = format.sampleRate
    let ch = Int(format.channelCount)
    let frames = AVAudioFrameCount(file.length)
    guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
      throw NSError(domain: "TransientLowbandAnalyze", code: 1, userInfo: [NSLocalizedDescriptionKey: "buffer alloc failed"])
    }
    try file.read(into: buf)
    guard let fdata = buf.floatChannelData else {
      throw NSError(domain: "TransientLowbandAnalyze", code: 2, userInfo: [NSLocalizedDescriptionKey: "expected float pcm"])
    }
    let n = Int(buf.frameLength)
    if n == 0 { throw NSError(domain: "TransientLowbandAnalyze", code: 3, userInfo: [NSLocalizedDescriptionKey: "empty audio"])    }

    // Mono sum for low-band metrics
    var mono = [Double](repeating: 0, count: n)
    for i in 0..<n {
      var s = Double(fdata[0][i])
      if ch >= 2 { s = 0.5 * (Double(fdata[0][i]) + Double(fdata[1][i])) }
      mono[i] = s
    }

    let lowBand = bands["low"] ?? [20,250]
    let subBand = bands["sub"] ?? [20,120]

    let low = bandpass(samples: mono, sr: sr, lowHz: lowBand[0], highHz: lowBand[1])
    let sub = bandpass(samples: mono, sr: sr, lowHz: subBand[0], highHz: subBand[1])

    let dur = Double(n) / sr
    return (sr, dur, low, sub)
  }

  static func metrics(sr: Double, dur: Double, low: [Double], sub: [Double]) -> TransientLowbandMetricsV1 {
    let lowRms = rms(low)
    let lowPeak = estimateTruePeakAbs(samples: low, oversample: 4)
    let subPeak = estimateTruePeakAbs(samples: sub, oversample: 4)

    let lowRmsDb = linToDbfs(lowRms)
    let lowPeakDb = linToDbfs(lowPeak)
    let subPeakDb = linToDbfs(subPeak)
    let crest = lowPeakDb - lowRmsDb

    return TransientLowbandMetricsV1(sampleRateHz: sr, durationS: dur, lowRmsDbfs: lowRmsDb,
                                    lowTruePeakDbfs: lowPeakDb, lowCrestDb: crest, subTruePeakDbfs: subPeakDb)
  }

  static func classify(m: TransientLowbandMetricsV1, th: Thresholds) -> (status: String, reasons: [String], thMap: [String: Double]) {
    var status = "pass"
    var reasons: [String] = []
    let thMap: [String: Double] = [
      "min_low_crest_db_warn": th.minLowCrestDbWarn,
      "min_low_crest_db_fail": th.minLowCrestDbFail,
      "max_low_rms_dbfs_warn": th.maxLowRmsDbfsWarn,
      "max_low_rms_dbfs_fail": th.maxLowRmsDbfsFail,
      "max_sub_true_peak_dbfs": th.maxSubTruePeakDbfs
    ]

    if m.lowCrestDb < th.minLowCrestDbFail {
      status = "fail"
      reasons.append("low_crest_db \(fmt(m.lowCrestDb)) < fail \(fmt(th.minLowCrestDbFail))")
    } else if m.lowCrestDb < th.minLowCrestDbWarn {
      status = maxStatus(status, "warn")
      reasons.append("low_crest_db \(fmt(m.lowCrestDb)) < warn \(fmt(th.minLowCrestDbWarn))")
    }

    if m.lowRmsDbfs > th.maxLowRmsDbfsFail {
      status = "fail"
      reasons.append("low_rms_dbfs \(fmt(m.lowRmsDbfs)) > fail \(fmt(th.maxLowRmsDbfsFail))")
    } else if m.lowRmsDbfs > th.maxLowRmsDbfsWarn {
      status = maxStatus(status, "warn")
      reasons.append("low_rms_dbfs \(fmt(m.lowRmsDbfs)) > warn \(fmt(th.maxLowRmsDbfsWarn))")
    }

    if m.subTruePeakDbfs > th.maxSubTruePeakDbfs {
      status = "fail"
      reasons.append("sub_true_peak_dbfs \(fmt(m.subTruePeakDbfs)) > \(fmt(th.maxSubTruePeakDbfs))")
    }

    return (status, reasons, thMap)
  }

  // DSP
  private static func bandpass(samples: [Double], sr: Double, lowHz: Double, highHz: Double) -> [Double] {
    let hp = onePoleHP(samples: samples, sr: sr, cutoff: lowHz)
    return onePoleLP(samples: hp, sr: sr, cutoff: highHz)
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
  private static func fmt(_ x: Double) -> String { String(format: "%.2f", x) }
}
