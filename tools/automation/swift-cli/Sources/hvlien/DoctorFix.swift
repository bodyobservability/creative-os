import Foundation
enum DoctorFix {
  static func run(context: DoctorContext) async -> [String] {
    var actions: [String] = []
    guard let regions = try? JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: context.regionsPath)),
          regions.cgRectTopLeft("os.file_dialog") != nil else {
      return ["fix: skipped (no os.file_dialog region)"]
    }
    let act = CGEventActuator()
    actions.append("fix: ESC x2")
    try? act.keyChord("ESC"); try? act.keyChord("ESC"); try? act.sleepMs(150)
    do {
      let cap = FrameCapture(); try await cap.start(); defer { Task { await cap.stop() } }
      let frame = try await cap.latestFrame(timeoutMs: 1500)
      let rect = regions.cgRectTopLeft("os.file_dialog")!
      let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
      let lines = try VisionOCR.recognizeLines(cgImage: crop)
      if let cancel = OCRMatcher.bestMatch(lines: lines, target: "Cancel", mode: "contains", minConf: 0.55) {
        let center = CGPoint(x: cancel.line.bbox.midX, y: cancel.line.bbox.midY)
        let screenPt = ScreenMapper.regionPointToScreen(regionRectTopLeft: rect, pointInRegion: center)
        actions.append("fix: click Cancel (OCR)")
        try act.home(); try act.moveTo(screenPointTopLeft: screenPt); try act.click(); try act.sleepMs(200)
      } else { actions.append("fix: Cancel not found via OCR") }
    } catch { actions.append("fix: error \(error.localizedDescription)") }
    return actions
  }
}
