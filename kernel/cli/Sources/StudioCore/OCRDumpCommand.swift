import Foundation
import ArgumentParser
import CoreGraphics

/// Debug tool to capture a frame, crop a region, OCR it, print top lines, and write artifacts.
struct OCRDumpCmd: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "ocr-dump", abstract: "Capture + OCR a named region (debug).")

  @OptionGroup var common: CommonOptions

  @Option(name: .long, help: "Region id from regions.v1.json, e.g., rack.macros")
  var region: String

  @Option(name: .long, help: "Output directory (defaults to \(RepoPaths.defaultRunsDir())/<run_id>/ocr_dump/<region>/)")
  var out: String?

  @Option(name: .long, help: "Max lines to print")
  var maxPrint: Int = 20

  func run() async throws {
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()

    let regions = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: common.regionsConfig))
    guard let rect = regions.cgRectTopLeft(region) else {
      throw ValidationError("Unknown region: \(region). Add it to \(common.regionsConfig).")
    }

    let outDir: URL = out.map { URL(fileURLWithPath: $0, isDirectory: true) }
      ?? ctx.runDir.appendingPathComponent("ocr_dump/\(sanitize(region))", isDirectory: true)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    let cap = FrameCapture()
    try await cap.start()
    defer { Task { await cap.stop() } }

    let frame = try await cap.latestFrame(timeoutMs: 1500)
    try ImageDump.savePNG(frame, to: outDir.appendingPathComponent("frame_full.png"))

    let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
    try ImageDump.savePNG(crop, to: outDir.appendingPathComponent("region.png"))

    let lines = try VisionOCR.recognizeLines(cgImage: crop)
    let dump = OCRDump(regionId: region, target: nil, matchMode: nil, minConf: nil, lines: lines.map(OCRDumpLine.init))
    try JSONIO.save(dump, to: outDir.appendingPathComponent("ocr.json"))

    print("\nOCR lines (top \(maxPrint)) for region '\(region)':")
    for ln in lines.prefix(maxPrint) {
      print(String(format: "  [%.2f] %@", ln.confidence, ln.text))
    }
    print("\nWrote: \(outDir.path)")
  }

  private func sanitize(_ s: String) -> String {
    s.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
  }
}
