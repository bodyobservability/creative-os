import Foundation
import ArgumentParser
import CoreGraphics

struct CalibrateRegions: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "calibrate-regions", abstract: "Draw region rectangles on a captured frame.")

  @OptionGroup var common: CommonOptions
  @Flag(name: .long, help: "Override station gating (dangerous).")
  var force: Bool = false
  @Option(name: .long) var out: String?

  func run() async throws {
    try StationGate.enforceOrThrow(force: force, anchorsPackHint: nil, commandName: "calibrate-regions")

    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()

    let outDir: URL = out.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? ctx.runDir.appendingPathComponent("region_calibration", isDirectory: true)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    let regions = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: common.regionsConfig))
    let cap = FrameCapture()
    try await cap.start()
    defer { Task { await cap.stop() } }

    let frame = try await cap.latestFrame()
    try ImageDump.savePNG(frame, to: outDir.appendingPathComponent("frame_full.png"))

    guard let overlay = RegionsOverlay.drawAllRegions(on: frame, regions: regions) else { throw ValidationError("Overlay failed") }
    try ImageDump.savePNG(overlay, to: outDir.appendingPathComponent("regions_overlay.png"))

    print("Wrote: \(outDir.path)")
  }
}
