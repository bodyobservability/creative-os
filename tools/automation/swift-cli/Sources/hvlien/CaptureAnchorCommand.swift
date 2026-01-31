import Foundation
import ArgumentParser
import CoreGraphics

struct CaptureAnchor: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "capture-anchor", abstract: "Capture full frame and region crop for anchor creation.")

  @OptionGroup var common: CommonOptions
  @Option(name: .long) var region: String
  @Option(name: .long) var out: String?
  @Option(name: .long) var frames: Int = 1
  @Option(name: .long) var intervalMs: Int = 150

  func run() async throws {
    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()
    let regions = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: common.regionsConfig))
    guard let rect = regions.cgRectTopLeft(region) else { throw ValidationError("Unknown region \(region)") }

    let outDir: URL = out.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? ctx.runDir.appendingPathComponent("anchor_capture/\(sanitize(region))", isDirectory: true)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    let cap = FrameCapture()
    try await cap.start()
    defer { Task { await cap.stop() } }

    let n = max(1, frames)
    for i in 0..<n {
      let full = try await cap.latestFrame()
      let crop = ScreenMapper.cropTopLeft(img: full, rectTopLeft: rect)
      try ImageDump.savePNG(full, to: outDir.appendingPathComponent("frame_full_\(i).png"))
      try ImageDump.savePNG(crop, to: outDir.appendingPathComponent("region_\(sanitize(region))_\(i).png"))
      if i < n - 1 {
        try await Task.sleep(nanoseconds: UInt64(intervalMs) * 1_000_000)
      }
    }

    print("Captured \(n) frame(s) to: \(outDir.path)")
  }

  private func sanitize(_ s: String) -> String { s.replacingOccurrences(of: "/", with: "_") }
}
