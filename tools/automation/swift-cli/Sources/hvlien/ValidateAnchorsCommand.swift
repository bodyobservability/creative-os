import Foundation
import ArgumentParser

struct ValidateAnchors: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "validate-anchors",
    abstract: "Validate anchor templates against current screen (OpenCV-enabled builds).")

  @OptionGroup var common: CommonOptions
  @Flag(name: .long, help: "Override station gating (dangerous).")
  var force: Bool = false
  @Option(name: .long) var pack: String
  @Option(name: .long) var out: String?

  func run() async throws {
    try StationGate.enforceOrThrow(force: force, anchorsPackHint: pack, commandName: "validate-anchors")

    let ctx = RunContext(common: common)
    try ctx.ensureRunDir()

    let outDir: URL = out.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? ctx.runDir.appendingPathComponent("anchor_validation", isDirectory: true)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

    let regions = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: common.regionsConfig))
    let packURL = URL(fileURLWithPath: pack, isDirectory: true)
    let manifestURL = packURL.appendingPathComponent("manifest.v1.json")

    #if OPENCV_ENABLED
    let manifest = try JSONIO.load(AnchorPackManifestV1.self, from: manifestURL)
    let matcher = AnchorMatcherOpenCV(packRoot: packURL)

    let cap = FrameCapture()
    try await cap.start()
    defer { Task { await cap.stop() } }
    let frame = try await cap.latestFrame(timeoutMs: 1500)
    try ImageDump.savePNG(frame, to: outDir.appendingPathComponent("frame_full.png"))

    var summary: [[String: Any]] = []
    for a in manifest.anchors {
      guard let searchRect = regions.cgRectTopLeft(a.regionId) else { continue }
      let m = matcher.find(anchorId: a.id, inFrame: frame, searchRegionTopLeft: searchRect)
      let score = m?.score ?? 0.0
      let pass = score >= (a.minScore ?? 0.9)
      summary.append(["anchor_id": a.id, "region_id": a.regionId, "score": score, "pass": pass])
    }
    let data = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: outDir.appendingPathComponent("summary.json"))
    print("Wrote: \(outDir.path)")
    #else
    print("validate-anchors requires OPENCV_ENABLED build. See V4_BUILD_OPENCV.md")
    #endif
  }
}
