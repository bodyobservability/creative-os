import Foundation
import CoreGraphics

enum ModalCancel {
  static let modalKeywords = ["open","save","cancel","replace","don’t save","dont save","are you sure","missing","locate","authorization","plugin"]

  static func modalPresent(lines: [OCRLine]) -> Bool {
    let blob = StudioNormV1.normNameV1(lines.map(\.text).joined(separator: " "))
    return modalKeywords.contains { k in
      let nk = StudioNormV1.normNameV1(k)
      return nk != "__invalid__" && blob.contains(nk)
    }
  }

  static func dismiss(capture: FrameCapture,
                      regions: RegionsV1,
                      actuator: Actuator,
                      anchorsPackPath: String?,
                      opId: String,
                      attempt: Int,
                      trace: TraceWriter?) async -> Bool {
    guard let dialogRect = regions.cgRectTopLeft("os.file_dialog") else { return false }

    trace?.event(opId: opId, attemptIndex: attempt, kind: "recovery", name: "modal_dismiss_start")

    try? actuator.keyChord("ESC")
    try? actuator.keyChord("ESC")
    try? actuator.sleepMs(150)

    if let present = await isPresent(capture: capture, dialogRect: dialogRect), !present { return true }

    #if OPENCV_ENABLED
    if let pack = anchorsPackPath,
       let cancelRect = regions.cgRectTopLeft("os.file_dialog.cancel_button") {
      do {
        let frame = try await capture.latestFrame(timeoutMs: 1500)
        let packURL = URL(fileURLWithPath: pack, isDirectory: true)
        let matcher = AnchorMatcherOpenCV(packRoot: packURL)
        if let m = matcher.find(anchorId: "macos.dialog.cancel_button", inFrame: frame, searchRegionTopLeft: cancelRect),
           m.score >= 0.88 {
          trace?.event(opId: opId, attemptIndex: attempt, kind: "recovery", name: "modal_click_cancel_anchor",
                      details: ["score": String(format: "%.3f", m.score)])
          let center = CGPoint(x: m.bboxTopLeft.midX, y: m.bboxTopLeft.midY)
          try? actuator.home()
          try? actuator.moveTo(screenPointTopLeft: center)
          try? actuator.click()
          try? actuator.sleepMs(200)
          if let present = await isPresent(capture: capture, dialogRect: dialogRect) { return !present }
        } else {
          trace?.event(opId: opId, attemptIndex: attempt, kind: "recovery", name: "modal_cancel_anchor_not_found")
        }
      } catch {
        trace?.event(opId: opId, attemptIndex: attempt, kind: "error", name: "modal_cancel_anchor_error", details: ["msg": error.localizedDescription])
      }
    }
    #endif

    // OCR fallback
    do {
      let frame = try await capture.latestFrame(timeoutMs: 1500)
      let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: dialogRect)
      let lines = try VisionOCR.recognizeLines(cgImage: crop)

      if let cancel = OCRMatcher.bestMatch(lines: lines, target: "Cancel", mode: "contains", minConf: 0.55) {
        let center = CGPoint(x: cancel.line.bbox.midX, y: cancel.line.bbox.midY)
        let screenPt = ScreenMapper.regionPointToScreen(regionRectTopLeft: dialogRect, pointInRegion: center)
        trace?.event(opId: opId, attemptIndex: attempt, kind: "recovery", name: "modal_click_cancel_ocr")
        try? actuator.home()
        try? actuator.moveTo(screenPointTopLeft: screenPt)
        try? actuator.click()
        try? actuator.sleepMs(200)
      } else {
        trace?.event(opId: opId, attemptIndex: attempt, kind: "recovery", name: "modal_cancel_not_found_ocr")
      }
    } catch {
      trace?.event(opId: opId, attemptIndex: attempt, kind: "error", name: "modal_dismiss_ocr_error", details: ["msg": error.localizedDescription])
    }

    if let present = await isPresent(capture: capture, dialogRect: dialogRect) {
      return !present
    }
    return false
  }

  private static func isPresent(capture: FrameCapture, dialogRect: CGRect) async -> Bool? {
    do {
      let frame = try await capture.latestFrame(timeoutMs: 1500)
      let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: dialogRect)
      let lines = try VisionOCR.recognizeLines(cgImage: crop)
      return modalPresent(lines: lines)
    } catch { return nil }
  }
}
