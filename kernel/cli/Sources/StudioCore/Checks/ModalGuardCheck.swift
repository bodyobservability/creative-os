import Foundation
struct ModalGuardCheck: DubSweeperCheck {
  let id = "modal_guard"
  func run(context: DubSweeperContext) async throws -> CheckResult {
    let art = DubSweeperArtifacts(baseDir: context.artifactsDir)
    let outDir = art.dir(for: id); try art.ensureDir(outDir)
    let regions = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: context.regionsPath))
    guard let rect = regions.cgRectTopLeft("os.file_dialog") else {
      return .skip(id, details:["reason":"os.file_dialog region not configured"], artifacts: [])
    }
    let cap = FrameCapture(); try await cap.start(); defer { Task { await cap.stop() } }
    let frame = try await cap.latestFrame(timeoutMs: 1500)
    let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
    let lines = try VisionOCR.recognizeLines(cgImage: crop)
    let blob = StudioNormV1.normNameV1(lines.map(\.text).joined(separator:" "))
    let present = ["open","save","cancel","are you sure","missing","locate","authorization","plugin"].contains { blob.contains(StudioNormV1.normNameV1($0)) }
    if context.modalTestMode == .detect {
      return present ? .fail(id, details:["mode":"detect","modal":"present"], artifacts: []) : .pass(id, details:["mode":"detect","modal":"absent"], artifacts: [])
    }
    if !present { return .skip(id, details:["mode":"active","reason":"no dialog detected; open Cmd+O dialog then rerun"], artifacts: []) }
    return .pass(id, details:["mode":"active","dismissed":"manual_or_fix"], artifacts: [])
  }
}
