import Foundation
import CoreGraphics

struct PreflightResult { let ok: Bool; let reasons: [String] }

enum Preflight {
  struct Config {
    var dumpOnSuccess: Bool = false
    var anchorMinScore: Double = 0.90
    var anchorsPackPath: String? = nil
  }

  static func run(capture: FrameCapture, regions: RegionsV1, plan: PlanV1, runDir: URL, config: Config) async -> PreflightResult {
    var reasons: [String] = []
    let dir = runDir.appendingPathComponent("failures/preflight", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    let required = ["browser.search","browser.results","tracks.list","device.chain"]
    for r in required { if regions.cgRectTopLeft(r) == nil { reasons.append("Missing region \(r)") } }
    if plan.ops.contains(where: { $0.action.type == "open_plugin_window" }) {
      for r in ["plugin.window","device.chain.controls"] { if regions.cgRectTopLeft(r) == nil { reasons.append("Missing region \(r) (plugin ops)") } }
    }
    if !reasons.isEmpty { dumpNote(dir, reasons); return PreflightResult(ok:false,reasons:reasons) }

    let frame: CGImage
    do { frame = try await capture.latestFrame(timeoutMs: 2000) }
    catch { reasons.append("Capture failed: \(error.localizedDescription)"); dumpNote(dir,reasons); return PreflightResult(ok:false,reasons:reasons) }

    try? ImageDump.savePNG(frame, to: dir.appendingPathComponent("frame_full.png"))

    func ocrCount(_ rid: String) -> Int {
      guard let rect = regions.cgRectTopLeft(rid) else { return 0 }
      let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
      let lines = (try? VisionOCR.recognizeLines(cgImage: crop)) ?? []
      return lines.count
    }
    if ocrCount("browser.search") < 1 { reasons.append("browser.search OCR empty") }
    if ocrCount("tracks.list") < 1 { reasons.append("tracks.list OCR empty") }
    if ocrCount("device.chain") < 1 { reasons.append("device.chain OCR empty") }

    if let rect = regions.cgRectTopLeft("os.file_dialog") {
      let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
      let lines = (try? VisionOCR.recognizeLines(cgImage: crop)) ?? []
      if ModalGuard.present(lines: lines) { reasons.append("Modal dialog detected (os.file_dialog)") }
    }

    #if OPENCV_ENABLED
    if let pack = config.anchorsPackPath {
      let packURL = URL(fileURLWithPath: pack, isDirectory: true)
      let matcher = AnchorMatcherOpenCV(packRoot: packURL)
      let checks: [(String,String)] = [("ableton.browser.search_field","browser.search"),("ableton.track_area_neutral","tracks.list")]
      var scores: [[String: Any]] = []
      for (aid,rid) in checks {
        if let rect = regions.cgRectTopLeft(rid), let m = matcher.find(anchorId: aid, inFrame: frame, searchRegionTopLeft: rect) {
          let pass = m.score >= config.anchorMinScore
          scores.append(["anchor_id":aid,"region_id":rid,"score":m.score,"pass":pass])
          if !pass { reasons.append("Anchor \(aid) score \(String(format:"%.3f",m.score)) < \(config.anchorMinScore)") }
        } else {
          scores.append(["anchor_id":aid,"region_id":rid,"score":0.0,"pass":false])
          reasons.append("Anchor \(aid) not found")
        }
      }
      if let data = try? JSONSerialization.data(withJSONObject: scores, options: [.prettyPrinted,.sortedKeys]) {
        try? data.write(to: dir.appendingPathComponent("anchor_scores.json"))
      }
    }
    #endif

    if reasons.isEmpty { if config.dumpOnSuccess { dumpNote(dir, ["OK"]) }; return PreflightResult(ok:true,reasons:[]) }
    dumpNote(dir, reasons); return PreflightResult(ok:false,reasons:reasons)
  }

  private static func dumpNote(_ dir: URL, _ reasons: [String]) {
    let txt = reasons.map { "- \($0)" }.joined(separator: "\n") + "\n"
    try? txt.data(using: .utf8)?.write(to: dir.appendingPathComponent("note.txt"))
  }
}
