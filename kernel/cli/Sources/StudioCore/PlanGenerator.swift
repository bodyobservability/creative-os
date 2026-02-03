import Foundation
import Yams

enum PlanGenerator {
  struct SerumPresetSpec { let name: String?; let path: String? }

  static func generate(specPath: String,
                       resolveReportURL: URL,
                       outPlanURL: URL,
                       regions: RegionsV1) throws {

    _ = regions
    let report = try JSONIO.load(ResolveReport.self, from: resolveReportURL)

    // Block apply if resolve prompts indicate missing deps
    let blockers: Set<String> = ["install_pack","install_plugin","install_plugin_or_pack","connect_controller","configure_controller"]
    let blocked = report.prompts.contains { blockers.contains($0.type) }

    // Use existing SpecCompiler if available; otherwise best-effort parse from YAML is already in v3 SpecCompiler.
    // Here we assume SpecCompiler.compile(specPath:packSignaturesPath:defaultFormats:) exists.
    let compiled = try SpecCompiler.compile(specPath: specPath,
                                            packSignaturesPath: nil,
                                            defaultFormats: ["au","vst3"])
    let serumPresetsByTrack = try parseSerumPresets(specPath: specPath)

    let trackOrder = orderedTracks(from: compiled.deviceRequests.map(\.id))
    var ops: [PlanOp] = []

    for track in trackOrder {
      ops.append(selectTrackOp(track))

      for req in compiled.deviceRequests where trackFromRequestId(req.id) == track {
        let resolvedName = resolvedNameFallback(requestId: req.id, requested: req.primary, report: report)
        let postText = postcheckText(for: req, resolvedName: resolvedName)

        ops.append(searchOp(req.id, resolvedName))
        ops.append(insertOp(req.id, resolvedName, postText))

        // Serum-specific augmentation
        if req.kindPreference.contains("plugin") && StudioNormV1.normNameV1(resolvedName).contains("serum") {
          ops.append(openSerumWindowOp(track))
          ops.append(verifySerumWindowOp(track))

          if let preset = serumPresetsByTrack[track] {
            if let name = preset.name {
              ops.append(contentsOf: serumPresetStrategyA(track: track, presetName: name))
            } else if let path = preset.path {
              ops.append(contentsOf: serumPresetStrategyB(track: track, presetPath: path))
            }
          }
        }
      }
    }

    let plan = PlanV1(schemaVersion: 1,
                      runId: ISO8601DateFormatter().string(from: Date()),
                      mode: blocked ? "dry_run" : "apply",
                      ops: ops)

    try JSONIO.save(plan, to: outPlanURL)
  }

  private static func resolvedNameFallback(requestId: String, requested: String, report: ResolveReport) -> String {
    // If you later add explicit resolved mapping to resolve_report.meta, consult it here.
    // For now, use requested.
    _ = requestId; _ = report
    return requested
  }

  // MARK: ops

  private static func selectTrackOp(_ track: String) -> PlanOp {
    PlanOp(
      id: "select_track_\(sanitize(track))",
      pre: nil,
      action: PlanAction(type: "click_ocr_match",
                         region: "tracks.list",
                         match: OCRMatchSpec(text: track, mode: "contains", minConf: 0.75)),
      post: [PlanAssert(type: "ui_text_contains", region: "tracks.list", text: track, minConf: 0.70)],
      recover: [
        PlanAction(type: "press_keys", keys: ["ESC"]),
        PlanAction(type: "press_keys", keys: ["ESC"]),
        PlanAction(type: "sleep", ms: 120)
      ],
      retries: 2,
      timeoutMs: 8000,
      notes: "Select track"
    )
  }

  private static func searchOp(_ reqId: String, _ query: String) -> PlanOp {
    PlanOp(
      id: "search_\(sanitize(reqId))",
      pre: nil,
      action: PlanAction(type: "search_browser",
                         anchorId: "ableton.browser.search_field",
                         fallbackRegion: "browser.search",
                         query: query),
      post: [PlanAssert(type: "ui_text_contains", region: "browser.results", text: query, minConf: 0.70)],
      recover: [PlanAction(type: "press_keys", keys: ["ESC"])],
      retries: 2,
      timeoutMs: 8000,
      notes: "Search browser"
    )
  }

  private static func insertOp(_ reqId: String, _ resolvedName: String, _ postText: String) -> PlanOp {
    PlanOp(
      id: "insert_\(sanitize(reqId))",
      pre: nil,
      action: PlanAction(type: "dblclick_ocr_match",
                         region: "browser.results",
                         match: OCRMatchSpec(text: resolvedName, mode: "contains", minConf: 0.70)),
      post: [PlanAssert(type: "ui_text_contains", region: "device.chain", text: postText, minConf: 0.70)],
      recover: [PlanAction(type: "press_keys", keys: ["ESC"])],
      retries: 1,
      timeoutMs: 8000,
      notes: "Insert device"
    )
  }

  private static func openSerumWindowOp(_ track: String) -> PlanOp {
    PlanOp(
      id: "open_serum_window_\(sanitize(track))",
      pre: [PlanAssert(type: "ui_text_contains", region: "device.chain", text: "Serum", minConf: 0.60)],
      action: PlanAction(type: "open_plugin_window",
                         pluginName: "Serum",
                         deviceChainText: "Serum",
                         openMethod: "anchor_button"),
      post: [],
      recover: [PlanAction(type: "press_keys", keys: ["ESC"])],
      retries: 2,
      timeoutMs: 8000,
      notes: "Open Serum window"
    )
  }

  private static func verifySerumWindowOp(_ track: String) -> PlanOp {
    PlanOp(
      id: "verify_serum_window_\(sanitize(track))",
      pre: nil,
      action: PlanAction(type: "sleep", ms: 200),
      post: [PlanAssert(type: "ui_anchor_present", anchorId: "serum.window.signature", minScore: 0.9, region: nil, text: nil, minConf: nil, pluginName: nil)],
      recover: [PlanAction(type: "press_keys", keys: ["ESC"])],
      retries: 2,
      timeoutMs: 8000,
      notes: "Verify Serum window open"
    )
  }

  private static func serumPresetStrategyA(track: String, presetName: String) -> [PlanOp] {
    let t = sanitize(track)
    return [
      PlanOp(id: "serum_focus_preset_\(t)", pre: nil,
            action: PlanAction(type: "click_anchor", anchorId: "serum.preset_field", fallbackRegion: "plugin.window"),
            post: [], recover: [PlanAction(type: "press_keys", keys: ["ESC"])], retries: 2, timeoutMs: 8000, notes: "Focus preset field"),
      PlanOp(id: "serum_cmd_a_\(t)", pre: nil,
            action: PlanAction(type: "press_keys", keys: ["CMD+A"]),
            post: [], recover: nil, retries: 1, timeoutMs: 2000, notes: "Select all"),
      PlanOp(id: "serum_type_\(t)", pre: nil,
            action: PlanAction(type: "type_text", text: presetName),
            post: [], recover: nil, retries: 1, timeoutMs: 8000, notes: "Type preset"),
      PlanOp(id: "serum_enter_\(t)", pre: nil,
            action: PlanAction(type: "press_keys", keys: ["ENTER"]),
            post: [], recover: nil, retries: 1, timeoutMs: 2000, notes: "Confirm"),
      PlanOp(id: "serum_verify_preset_\(t)", pre: nil,
            action: PlanAction(type: "sleep", ms: 250),
            post: [PlanAssert(type: "ui_text_contains", region: "plugin.window", text: presetName, minConf: 0.65)],
            recover: [PlanAction(type: "press_keys", keys: ["ESC"])],
            retries: 2, timeoutMs: 8000, notes: "Verify preset loaded")
    ]
  }

  private static func serumPresetStrategyB(track: String, presetPath: String) -> [PlanOp] {
    let t = sanitize(track)
    return [
      PlanOp(id: "serum_menu_\(t)", pre: nil,
            action: PlanAction(type: "click_anchor", anchorId: "serum.menu_preset", fallbackRegion: "plugin.window"),
            post: [], recover: [PlanAction(type: "press_keys", keys: ["ESC"])], retries: 2, timeoutMs: 8000, notes: "Open menu"),
      PlanOp(id: "serum_load_\(t)", pre: nil,
            action: PlanAction(type: "click_anchor", anchorId: "serum.menu_load_preset", fallbackRegion: "plugin.window"),
            post: [], recover: [PlanAction(type: "press_keys", keys: ["ESC"])], retries: 2, timeoutMs: 8000, notes: "Click Load Preset"),
      PlanOp(id: "dlg_focus_\(t)", pre: nil,
            action: PlanAction(type: "click_anchor", anchorId: "macos.open_dialog.filename_field", fallbackRegion: "os.file_dialog.filename_field"),
            post: [], recover: [PlanAction(type: "press_keys", keys: ["ESC"])], retries: 2, timeoutMs: 8000, notes: "Focus filename field"),
      PlanOp(id: "dlg_type_\(t)", pre: nil,
            action: PlanAction(type: "type_text", text: presetPath),
            post: [], recover: nil, retries: 1, timeoutMs: 8000, notes: "Type preset path"),
      PlanOp(id: "dlg_open_\(t)", pre: nil,
            action: PlanAction(type: "click_anchor", anchorId: "macos.open_dialog.open_button", fallbackRegion: "os.file_dialog.open_button"),
            post: [], recover: nil, retries: 2, timeoutMs: 8000, notes: "Click Open"),
      PlanOp(id: "serum_verify_preset_file_\(t)", pre: nil,
            action: PlanAction(type: "sleep", ms: 300),
            post: [PlanAssert(type: "ui_text_contains", region: "plugin.window", text: fileNameFromPath(presetPath), minConf: 0.55)],
            recover: [PlanAction(type: "press_keys", keys: ["ESC"])],
            retries: 2, timeoutMs: 8000, notes: "Verify preset (file)")
    ]
  }

  // MARK parsing

  private static func parseSerumPresets(specPath: String) throws -> [String: SerumPresetSpec] {
    let yamlText = try String(contentsOfFile: specPath, encoding: .utf8)
    let loaded = try Yams.load(yaml: yamlText)
    guard let root = loaded as? [String: Any] else { return [:] }

    var out: [String: SerumPresetSpec] = [:]
    guard let tracks = root["tracks"] as? [Any] else { return [:] }
    for t in tracks {
      guard let tm = t as? [String: Any] else { continue }
      let tname = tm["name"] as? String ?? ""
      guard let chain = tm["chain"] as? [Any] else { continue }
      for devAny in chain {
        guard let dev = devAny as? [String: Any] else { continue }
        guard let plugin = dev["plugin"] as? [String: Any] else { continue }
        guard let preset = plugin["preset"] as? [String: Any] else { continue }
        let name = preset["name"] as? String
        let path = preset["path"] as? String
        if (name != nil || path != nil) && !tname.isEmpty {
          out[tname] = SerumPresetSpec(name: name, path: path)
        }
      }
    }
    return out
  }

  private static func fileNameFromPath(_ p: String) -> String {
    (p as NSString).lastPathComponent.replacingOccurrences(of: ".fxp", with: "")
  }

  // MARK helpers

  private static func postcheckText(for req: DeviceRequest, resolvedName: String) -> String {
    if req.kindPreference.contains("plugin") {
      let n = StudioNormV1.normNameV1(resolvedName)
      if n.contains("serum") { return "Serum" }
      return resolvedName.split(separator: " ").first.map(String.init) ?? resolvedName
    }
    return resolvedName
  }

  private static func orderedTracks(from requestIds: [String]) -> [String] {
    var seen = Set<String>(); var out: [String] = []
    for id in requestIds {
      let t = trackFromRequestId(id)
      if !t.isEmpty && seen.insert(t).inserted { out.append(t) }
    }
    return out
  }

  private static func trackFromRequestId(_ id: String) -> String {
    guard let r = id.range(of: "track:") else { return "" }
    let rest = id[r.upperBound...]
    if let slash = rest.firstIndex(of: "/") { return String(rest[..<slash]) }
    return ""
  }

  private static func sanitize(_ s: String) -> String {
    s.replacingOccurrences(of: "/", with: "_")
     .replacingOccurrences(of: ":", with: "_")
     .replacingOccurrences(of: " ", with: "_")
  }
}
