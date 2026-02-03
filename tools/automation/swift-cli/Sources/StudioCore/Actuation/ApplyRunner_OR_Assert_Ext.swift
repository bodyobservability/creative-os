import Foundation

extension ApplyRunner {
  func regionContainsAnyToken(regionId: String, tokens: [String], minConf: Double) async throws -> Bool {
    guard let rect = regions.cgRectTopLeft(regionId) else { return false }
    let frame = try await capture.latestFrame(timeoutMs: 1500)
    let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
    let lines = try VisionOCR.recognizeLines(cgImage: crop).filter { $0.confidence >= minConf }
    for t in tokens {
      if OCRMatcher.bestMatch(lines: lines, target: t, mode: "contains", minConf: minConf) != nil {
        return true
      }
    }
    return false
  }
}
