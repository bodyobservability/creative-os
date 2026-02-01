import Foundation
import ArgumentParser
import CoreMIDI
import Yams
import CoreGraphics

struct VRL: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "vrl",
    abstract: "Voice Runtime Layer tools (v9.x).",
    subcommands: [Validate.self]
  )

  struct Validate: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "validate",
      abstract: "Validate v9.3 Ableton runtime mapping prerequisites and emit a receipt (v9.4)."
    )

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Path to v9.3 mapping spec YAML.")
    var mapping: String = WubDefaults.profileSpecPath("voice_runtime/v9_3_ableton_mapping.v1.yaml")

    @Option(name: .long, help: "Regions config path (must include tracks.list, device.chain, rack.macros).")
    var regions: String = "tools/automation/swift-cli/config/regions.v1.json"

    @Option(name: .long, help: "Output receipt path (default: runs/<run_id>/vrl_mapping_receipt.v1.json).")
    var out: String?

    @Flag(name: .long, help: "Also dump OCR JSON+PNGs for key regions (recommended).")
    var dump: Bool = true

    func run() async throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

      let mappingText = try String(contentsOfFile: mapping, encoding: .utf8)
      let mappingRoot = try (Yams.load(yaml: mappingText) as? [String: Any]) ?? [:]

      let midiBus = ((mappingRoot["midi"] as? [String: Any])?["bus"] as? String) ?? "WUB_VOICE"
      let midiChannel = ((mappingRoot["midi"] as? [String: Any])?["channel"] as? Int) ?? 1

      // Collect expectations from mapping
      let macroNames = ["Energy","Motion","Tone","Texture","Width","Space","Impact","Morph"]
      let trackNames = extractTrackNames(mappingRoot)  // e.g. BASS, VOX
      let clipNames = extractClipNames(mappingRoot)    // e.g. RISER

      var checks: [VRLCheckEntry] = []
      var reasons: [String] = []
      var artifacts: [String: String] = [:]

      // Check 1: MIDI dest exists
      let midiOk = midiDestinationExists(contains: midiBus)
      checks.append(.init(id: "midi_bus_present",
                          status: midiOk ? "pass" : "fail",
                          details: ["midi_bus": midiBus, "channel": String(midiChannel)]))
      if !midiOk { reasons.append("midi bus not found: \(midiBus)") }

      // Check 2: Regions sanity
      let regionsDoc = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: regions))
      let requiredRegions = ["tracks.list","device.chain","rack.macros"]
      let missing = requiredRegions.filter { regionsDoc.cgRectTopLeft($0) == nil }
      checks.append(.init(id: "regions_present",
                          status: missing.isEmpty ? "pass" : "fail",
                          details: ["regions": regions, "missing": missing.joined(separator: ",")]))
      if !missing.isEmpty { reasons.append("missing regions: \(missing.joined(separator: ","))") }

      // Capture a single frame once for OCR checks
      let cap = FrameCapture()
      try await cap.start()
      defer { Task { await cap.stop() } }
      let frame = try await cap.latestFrame(timeoutMs: 2000)
      if dump {
        try ImageDump.savePNG(frame, to: runDir.appendingPathComponent("frame_full.png"))
        artifacts["frame_full_png"] = "runs/\(runId)/frame_full.png"
      }

      // Check 3: tracks present (OCR contains for each trackName)
      let tracksOk = try await ocrContainsAll(frame: frame, regions: regionsDoc, regionId: "tracks.list", tokens: trackNames, runDir: runDir, dump: dump, dumpPrefix: "tracks")
      checks.append(.init(id: "tracks_present",
                          status: tracksOk.ok ? (trackNames.isEmpty ? "skip" : "pass") : "fail",
                          details: ["expected": trackNames.joined(separator: ","), "missing": tracksOk.missing.joined(separator: ",")]))
      if !tracksOk.ok && !trackNames.isEmpty { reasons.append("missing tracks: \(tracksOk.missing.joined(separator:","))") }

      // Check 4: macro labels present (ABI)
      let macrosOk = try await ocrContainsAll(frame: frame, regions: regionsDoc, regionId: "rack.macros", tokens: macroNames, runDir: runDir, dump: dump, dumpPrefix: "macros")
      checks.append(.init(id: "abi_macro_labels_present",
                          status: macrosOk.ok ? "pass" : "fail",
                          details: ["expected": macroNames.joined(separator: ","), "missing": macrosOk.missing.joined(separator: ",")]))
      if !macrosOk.ok { reasons.append("missing macro labels in rack.macros") }

      // Check 5: clip names present in tracks list (best-effort; clips may not appear in tracks list)
      if !clipNames.isEmpty {
        let clipOk = try await ocrContainsAny(frame: frame, regions: regionsDoc, regionId: "tracks.list", tokens: clipNames, runDir: runDir, dump: dump, dumpPrefix: "clips")
        checks.append(.init(id: "clip_name_visible_best_effort",
                            status: clipOk ? "pass" : "warn",
                            details: ["expected_any": clipNames.joined(separator: ",")]))
        if !clipOk { reasons.append("clip name not visible in tracks.list (ok if clip view hidden)") }
      } else {
        checks.append(.init(id: "clip_name_visible_best_effort", status: "skip", details: ["expected_any": ""]))
      }

      // Overall status
      let status: String = reasons.contains(where: { $0.contains("missing regions") || $0.contains("midi bus not found") || $0.contains("missing macro") }) ? "fail" :
                           (reasons.isEmpty ? "pass" : "warn")

      let receipt = VRLValidateReceiptV1(schemaVersion: 1,
                                         runId: runId,
                                         timestamp: ISO8601DateFormatter().string(from: Date()),
                                         mappingSpec: mapping,
                                         status: status,
                                         checks: checks,
                                         artifacts: artifacts,
                                         reasons: reasons)

      let outPath = out ?? runDir.appendingPathComponent("vrl_mapping_receipt.v1.json").path
      try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))
      print("status: \(status)")
      print("receipt: \(outPath)")
      if status == "fail" { throw ExitCode(1) }
    }

    // MARK: extraction helpers

    private func extractTrackNames(_ root: [String: Any]) -> [String] {
      var names: [String] = []
      if let tracks = root["tracks"] as? [String: Any] {
        for (_, v) in tracks {
          if let m = v as? [String: Any], let tgt = m["target"] as? [String: Any], let tn = tgt["track_name"] as? String {
            names.append(tn)
          }
        }
      }
      return Array(Set(names)).sorted()
    }

    private func extractClipNames(_ root: [String: Any]) -> [String] {
      var names: [String] = []
      if let arr = root["arrangement"] as? [String: Any] {
        for (_, v) in arr {
          if let m = v as? [String: Any], let tgt = m["target"] as? [String: Any], let cn = tgt["clip_name"] as? String {
            names.append(cn)
          }
        }
      }
      return Array(Set(names)).sorted()
    }

    // MARK: MIDI check

    private func midiDestinationExists(contains needle: String) -> Bool {
      let n = MIDIGetNumberOfDestinations()
      for i in 0..<n {
        let e = MIDIGetDestination(i)
        if e == 0 { continue }
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(e, kMIDIPropertyName, &name)
        let s = (name?.takeRetainedValue() as String?) ?? ""
        if s.lowercased().contains(needle.lowercased()) { return true }
      }
      return false
    }

    // MARK: OCR helpers

    private struct OCRAllResult { let ok: Bool; let missing: [String] }

    private func ocrContainsAll(frame: CGImage, regions: RegionsV1, regionId: String, tokens: [String], runDir: URL, dump: Bool, dumpPrefix: String) async throws -> OCRAllResult {
      guard !tokens.isEmpty else { return .init(ok: true, missing: []) }
      guard let rect = regions.cgRectTopLeft(regionId) else { return .init(ok: false, missing: tokens) }
      let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
      if dump {
        let png = runDir.appendingPathComponent("\(dumpPrefix)_\(sanitize(regionId)).png")
        try ImageDump.savePNG(crop, to: png)
      }
      let lines = try VisionOCR.recognizeLines(cgImage: crop)
      if dump {
        let dump = OCRDump(regionId: regionId, target: nil, matchMode: nil, minConf: nil, lines: lines.map(OCRDumpLine.init))
        try JSONIO.save(dump, to: runDir.appendingPathComponent("\(dumpPrefix)_\(sanitize(regionId)).ocr.json"))
      }
      let blob = StudioNormV1.normNameV1(lines.map(\.text).joined(separator: " "))
      var missing: [String] = []
      for t in tokens {
        let nt = StudioNormV1.normNameV1(t)
        if nt == "__invalid__" { continue }
        if !blob.contains(nt) { missing.append(t) }
      }
      return .init(ok: missing.isEmpty, missing: missing)
    }

    private func ocrContainsAny(frame: CGImage, regions: RegionsV1, regionId: String, tokens: [String], runDir: URL, dump: Bool, dumpPrefix: String) async throws -> Bool {
      guard !tokens.isEmpty else { return true }
      guard let rect = regions.cgRectTopLeft(regionId) else { return false }
      let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
      if dump {
        try ImageDump.savePNG(crop, to: runDir.appendingPathComponent("\(dumpPrefix)_\(sanitize(regionId)).png"))
      }
      let lines = try VisionOCR.recognizeLines(cgImage: crop)
      let blob = StudioNormV1.normNameV1(lines.map(\.text).joined(separator: " "))
      for t in tokens {
        let nt = StudioNormV1.normNameV1(t)
        if nt == "__invalid__" { continue }
        if blob.contains(nt) { return true }
      }
      return false
    }

    private func sanitize(_ s: String) -> String {
      s.replacingOccurrences(of: ".", with: "_").replacingOccurrences(of: "/", with: "_")
    }
  }
}
