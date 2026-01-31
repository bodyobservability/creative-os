import Foundation
import CoreGraphics
struct AbletonLivenessCheck: DoctorCheck {
  let id = "ableton_liveness"
  func run(context: DoctorContext) async throws -> CheckResult {
    let art = DoctorArtifacts(baseDir: context.artifactsDir)
    let outDir = art.dir(for: id); try art.ensureDir(outDir)
    let regions = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: context.regionsPath))
    for r in ["browser.search","tracks.list","device.chain"] {
      if regions.cgRectTopLeft(r) == nil { return .fail(id, details: ["reason":"missing region \(r)"], artifacts: []) }
    }
    let cap = FrameCapture(); try await cap.start(); defer { Task { await cap.stop() } }
    let frame = try await cap.latestFrame(timeoutMs: 1500)
    try ImageDump.savePNG(frame, to: art.path(id,"frame_full.png"))
    let b = try ocr("browser.search", frame, regions, art)
    let t = try ocr("tracks.list", frame, regions, art)
    let d = try ocr("device.chain", frame, regions, art)
    if b.isEmpty { return .fail(id, details:["reason":"browser.search OCR empty","hint":"Show Browser + search field"], artifacts:[art.rel(id,"frame_full.png")]) }
    if t.isEmpty { return .fail(id, details:["reason":"tracks.list OCR empty","hint":"Show track headers"], artifacts:[art.rel(id,"frame_full.png")]) }
    if d.isEmpty { return .fail(id, details:["reason":"device.chain OCR empty","hint":"Open Device View (Cmd+Opt+L)"], artifacts:[art.rel(id,"frame_full.png")]) }
    return .pass(id, details:["browser_lines":"\(b.count)","tracks_lines":"\(t.count)","chain_lines":"\(d.count)"], artifacts:[art.rel(id,"frame_full.png")])
  }
  private func ocr(_ rid: String, _ frame: CGImage, _ regions: RegionsV1, _ art: DoctorArtifacts) throws -> [OCRLine] {
    let rect = regions.cgRectTopLeft(rid)!
    let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
    try ImageDump.savePNG(crop, to: art.path(id,"region_\(rid).png"))
    let lines = try VisionOCR.recognizeLines(cgImage: crop)
    let dump = OCRDump(regionId: rid, target: nil, matchMode: nil, minConf: nil, lines: lines.map(OCRDumpLine.init))
    try JSONIO.save(dump, to: art.path(id,"ocr_\(rid).json"))
    return lines
  }
}
