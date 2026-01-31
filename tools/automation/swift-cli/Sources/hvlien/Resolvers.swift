import Foundation
import Vision
import ScreenCaptureKit
import CoreGraphics
import CoreImage
import CoreMedia

enum ResolvePhase {
  static func runResolve(specPath: String,
                         inventoryURL: URL,
                         controllersURL: URL,
                         substitutionsPath: String,
                         recommendationsPath: String,
                         packSignaturesPath: String,
                         preferredFormats: [String]) throws -> ResolveReport {
    let compiled = try SpecCompiler.compile(specPath: specPath, packSignaturesPath: packSignaturesPath, defaultFormats: preferredFormats)
    let inv = try JSONIO.load(InventoryDoc.self, from: inventoryURL)
    let ctrls = try JSONIO.load(ControllersInventoryDoc.self, from: controllersURL)
    _ = try JSONIO.load(SubstitutionsDoc.self, from: URL(fileURLWithPath: substitutionsPath))
    let recs = try? JSONIO.load(RecommendationsDoc.self, from: URL(fileURLWithPath: recommendationsPath))
    let packs = try JSONDecoder().decode(PackSignaturesDoc.self, from: Data(contentsOf: URL(fileURLWithPath: packSignaturesPath)))

    var prompts: [Prompt] = []
    var results: [ResolveResult] = []

    // Device resolution: required missing -> prompt + recommendations by tag
    for r in compiled.deviceRequests {
      let found = inv.items.contains { HVLIENNormV1.normNameV1($0.displayName) == HVLIENNormV1.normNameV1(r.primary) }
      results.append(ResolveResult(requestId: r.id, decision: found ? "ok" : (r.required ? "failed" : "skipped")))
      if !found && r.required {
        var msg = "Required device/plugin '\(r.primary)' not found in inventory."
        if let recs = recs {
          let best = r.tags.compactMap { recs.tags[$0] }.sorted { $0.priority > $1.priority }.first
          if let best = best {
            msg += "\n\nRecommendations: \(best.why)\n"
            for s in best.suggestions.prefix(3) {
              msg += "• \(s.type): \(s.name)\(s.vendor != nil ? " — \(s.vendor!)" : "")\n"
            }
          }
        }
        prompts.append(Prompt(type: "install_plugin_or_pack", title: "Missing required device: \(r.primary)", message: msg, relatedRequestId: r.id))
      }
    }

    // Controllers: required but not present -> prompt, MPK Port2 check -> configure
    for c in compiled.controllerRequests {
      let tokens = c.expectedNameContains.map { HVLIENNormV1.normNameV1($0) }
      let best = ctrls.devices.first { d in tokens.allSatisfy { d.normName.contains($0) } }
      if best == nil && c.required {
        prompts.append(Prompt(type: "connect_controller", title: "Required controller not detected", message: "Connect and power on the controller, then re-run A0.", relatedRequestId: c.id))
      } else if let d = best, c.required, d.normName.contains("mpk") && !mpkPort2Present(d) {
        prompts.append(Prompt(type: "configure_controller", title: "MPK mini IV Port 2 not detected", message: "Set Ableton Preferences → Link/Tempo/MIDI: Control Surface=MPK mini IV, Input=Port 2, Output=Port 2. Then re-run A0.", relatedRequestId: c.id))
      }
    }

    // Packs: evaluate via signature tokens in evidence ocr_text
    for pc in compiled.packChecks {
      if let pack = packs.packs.first(where: { $0.packId == pc.packId }) {
        let hits = pack.signatureTokens.reduce(0) { acc, t in
          let needle = HVLIENNormV1.normNameV1(t.expectContains)
          let ok = inv.items.flatMap { $0.evidence.samples }.contains { s in s.confidence >= pack.confidenceThreshold && HVLIENNormV1.normNameV1(s.ocrText).contains(needle) }
          return acc + (ok ? 1 : 0)
        }
        if hits < pack.minHits && pc.required {
          let because = pc.becauseTags.isEmpty ? "" : ("\n\nBecause tags: " + pc.becauseTags.joined(separator: ", "))
          prompts.append(Prompt(type: "install_pack", title: pack.installPrompt.title, message: pack.installPrompt.message + because, relatedRequestId: pc.id))
        }
      }
    }

    return ResolveReport(schemaVersion: 1, generatedAt: ISO8601DateFormatter().string(from: Date()), environment: ["os":"macos"], results: results, prompts: prompts, meta: nil)
  }
}

enum CapturePhase {
  // v3 automatic mode: ScreenCaptureKit + Vision OCR on a configured region (no paste).
  // Assumptions:
  // - Ableton is visible on the main display.
  // - Browser results list is visible at the configured rect.
  //
  // Configuration:
  // - If a JSON file exists at `tools/automation/swift-cli/config/regions.v1.json`, we use:
  //     regions.ableton.browser.results_list {x,y,w,h}
  // - Otherwise we fall back to a conservative default rect for a left-side browser list.
  //
  // Note: This does NOT type into Ableton. It simply OCRs whatever results are currently visible.
  static func run(runId: String, outInventoryURL: URL) async throws {
    let region = try loadResultsRegionRect()

    // Start capture stream (main display)
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard let display = content.displays.first else {
      throw NSError(domain: "CapturePhase", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found for ScreenCaptureKit."])
    }

    let filter = SCContentFilter(display: display, excludingWindows: [])
    let conf = SCStreamConfiguration()
    conf.width = display.width
    conf.height = display.height
    conf.minimumFrameInterval = CMTime(value: 1, timescale: 2) // ~2 fps
    conf.queueDepth = 3
    conf.capturesAudio = false

    let stream = SCStream(filter: filter, configuration: conf, delegate: nil)
    let collector = FrameCollector()
    try stream.addStreamOutput(collector, type: .screen, sampleHandlerQueue: DispatchQueue(label: "sc.frame.q"))
    try await stream.startCapture()

    defer { Task { try? await stream.stopCapture() } }

    // Collect a few frames to avoid transient blank frames
    let frames = try await collector.takeFrames(count: 3, timeoutSec: 2.5)
    guard let last = frames.last else {
      throw NSError(domain: "CapturePhase", code: 2, userInfo: [NSLocalizedDescriptionKey: "No frames captured."])
    }

    // Crop + OCR
    let cropped = cropTopLeft(img: last, rectTopLeft: region)
    let lines = try ocrLines(cropped)

    let builder = InventoryBuilderV1()
    for ln in lines {
      let t = ln.text.trimmingCharacters(in: .whitespacesAndNewlines)
      if t.isEmpty { continue }
      // Confidence gating is applied inside InventoryBuilderV1.
      let kind = t.lowercased().contains("serum") ? "plugin" : "ableton_audio_effect"
      let fmt: String? = (kind == "plugin") ? "au" : nil
      let vendor: String? = (kind == "plugin") ? "Xfer" : "Ableton"
      let sample = EvidenceSample(runId: runId, frameTsMs: 0, regionId: "capture.results_list", ocrText: t, confidence: ln.confidence, screenshotRelpath: nil)
      builder.ingest(InventorySighting(displayName: t, kind: kind, format: fmt, vendor: vendor, tags: [], sample: sample))
    }

    let items = builder.finalize()
    let doc = InventoryDoc(
      schemaVersion: 1,
      generatedAt: ISO8601DateFormatter().string(from: Date()),
      environment: ["os":"macos","ableton":"12.3"],
      source: ["method":"ableton_browser_search_ocr"],
      items: items
    )
    try JSONIO.save(doc, to: outInventoryURL)

    if items.isEmpty {
      print("A0 warning: inventory is empty. Ensure Ableton is visible and the Browser results list region is correctly configured.")
    } else {
      print("A0 inventory: captured \(items.count) unique items.")
    }
  }

  // MARK: - Region config

  private struct RegionsConfig: Decodable {
    struct Rect: Decodable { let x: Int; let y: Int; let w: Int; let h: Int }
    let schemaVersion: Int
    let regions: [String: Rect]
    enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version"; case regions }
  }

  /// Returns a rect in *top-left* display coordinates.
  private static func loadResultsRegionRect() throws -> CGRect {
    let fm = FileManager.default
    let path = "tools/automation/swift-cli/config/regions.v1.json"
    if fm.fileExists(atPath: path) {
      let cfg = try JSONDecoder().decode(RegionsConfig.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
      if let r = cfg.regions["ableton.browser.results_list"] {
        return CGRect(x: r.x, y: r.y, width: r.w, height: r.h)
      }
    }
    // Fallback: left-side browser list on typical Ableton layout (tune as needed)
    return CGRect(x: 40, y: 140, width: 560, height: 900)
  }

  // MARK: - OCR + image helpers

  private struct OCRLine { let text: String; let confidence: Double }

  private static func ocrLines(_ img: CGImage) throws -> [OCRLine] {
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .fast
    req.usesLanguageCorrection = false
    req.minimumTextHeight = 0.02
    req.recognitionLanguages = ["en-US"]

    let handler = VNImageRequestHandler(cgImage: img, options: [:])
    try handler.perform([req])

    guard let obs = req.results else { return [] }
    var out: [OCRLine] = []
    out.reserveCapacity(obs.count)

    for o in obs {
      guard let top = o.topCandidates(1).first else { continue }
      out.append(OCRLine(text: top.string, confidence: Double(top.confidence)))
    }

    // Sort top-to-bottom by bounding box (optional polish)
    return out
  }

  /// Crop using a rect specified in *top-left* coordinates.
  private static func cropTopLeft(img: CGImage, rectTopLeft: CGRect) -> CGImage {
    // Convert top-left rect to CoreGraphics bottom-left rect
    let imgH = CGFloat(img.height)
    let cgRect = CGRect(
      x: rectTopLeft.origin.x,
      y: imgH - rectTopLeft.origin.y - rectTopLeft.size.height,
      width: rectTopLeft.size.width,
      height: rectTopLeft.size.height
    ).integral

    return img.cropping(to: cgRect) ?? img
  }
}
