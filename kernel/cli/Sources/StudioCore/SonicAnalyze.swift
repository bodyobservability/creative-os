import Foundation
import AVFoundation

enum SonicAnalyze {

  struct Thresholds {
    var maxTruePeakDbfs: Double = -1.0
    var maxDcOffsetAbs: Double = 0.02
    var minStereoCorrelation: Double = -0.2
    var maxRmsDbfsWarn: Double = -10.0
    var maxRmsDbfsFail: Double = -6.0
  }

  static func analyze(url: URL) throws -> (metrics: SonicMetricsV1, peak: Double, truePeak: Double) {
    let file = try AVAudioFile(forReading: url)
    let format = file.processingFormat
    let sr = format.sampleRate
    let ch = Int(format.channelCount)
    let frameCount = AVAudioFrameCount(file.length)

    guard let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
      throw NSError(domain: "SonicAnalyze", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate buffer"])
    }
    try file.read(into: buf)

    guard let floatData = buf.floatChannelData else {
      throw NSError(domain: "SonicAnalyze", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected float PCM"])
    }

    let n = Int(buf.frameLength)
    if n == 0 { throw NSError(domain: "SonicAnalyze", code: 3, userInfo: [NSLocalizedDescriptionKey: "Empty audio"])    }

    var peakAbs: Double = 0
    var sumSq: Double = 0
    var sum: Double = 0

    // For correlation
    var corr: Double? = nil
    if ch >= 2 {
      var sumXY: Double = 0
      var sumX2: Double = 0
      var sumY2: Double = 0
      for i in 0..<n {
        let x = Double(floatData[0][i])
        let y = Double(floatData[1][i])
        sumXY += x * y
        sumX2 += x * x
        sumY2 += y * y
      }
      let denom = (sumX2.squareRoot() * sumY2.squareRoot())
      corr = denom > 0 ? (sumXY / denom) : nil
    }

    for c in 0..<ch {
      for i in 0..<n {
        let x = Double(floatData[c][i])
        let ax = abs(x)
        if ax > peakAbs { peakAbs = ax }
        sumSq += x * x
        sum += x
      }
    }

    let totalSamples = Double(n * ch)
    let rms = (sumSq / totalSamples).squareRoot()
    let dc = sum / totalSamples

    // Peak dBFS
    let peakDbfs = linToDbfs(peakAbs)
    let rmsDbfs = linToDbfs(rms)

    // "True peak" approximation: 4x oversampled peak via linear interpolation
    let truePeakAbs = estimateTruePeakAbs(floatData: floatData, channels: ch, frames: n, oversample: 4)
    let truePeakDbfs = linToDbfs(truePeakAbs)

    let crest = peakDbfs - rmsDbfs
    let duration = Double(n) / sr

    let metrics = SonicMetricsV1(
      sampleRateHz: sr,
      channels: ch,
      durationS: duration,
      truePeakDbfs: truePeakDbfs,
      peakDbfs: peakDbfs,
      rmsDbfs: rmsDbfs,
      dcOffset: dc,
      crestFactorDb: crest,
      stereoCorrelation: corr
    )
    return (metrics, peakAbs, truePeakAbs)
  }

  static func classify(metrics: SonicMetricsV1, thresholds: Thresholds) -> (status: String, reasons: [String], th: [String: Double]) {
    var status = "pass"
    var reasons: [String] = []

    let th: [String: Double] = [
      "max_true_peak_dbfs": thresholds.maxTruePeakDbfs,
      "max_dc_offset_abs": thresholds.maxDcOffsetAbs,
      "min_stereo_correlation": thresholds.minStereoCorrelation,
      "max_rms_dbfs_warn": thresholds.maxRmsDbfsWarn,
      "max_rms_dbfs_fail": thresholds.maxRmsDbfsFail
    ]

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

    return (status, reasons, th)
  }

  private static func estimateTruePeakAbs(floatData: UnsafePointer<UnsafeMutablePointer<Float>>,
                                         channels: Int,
                                         frames: Int,
                                         oversample: Int) -> Double {
    if oversample <= 1 { return 0 }
    var tp: Double = 0
    // Linear interpolation oversampling between samples (cheap approximation)
    for c in 0..<channels {
      for i in 0..<(frames-1) {
        let a = Double(floatData[c][i])
        let b = Double(floatData[c][i+1])
        for k in 0..<oversample {
          let t = Double(k) / Double(oversample)
          let y = a + (b - a) * t
          let ay = abs(y)
          if ay > tp { tp = ay }
        }
      }
    }
    return tp
  }

  private static func linToDbfs(_ x: Double) -> Double {
    let v = max(x, 1e-12)
    return 20.0 * log10(v)
  }

  private static func maxStatus(_ a: String, _ b: String) -> String {
    // pass < warn < fail
    let rank: [String: Int] = ["pass": 0, "warn": 1, "fail": 2]
    return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a : b
  }

  private static func fmt(_ x: Double) -> String { String(format: "%.2f", x) }
}
