import Foundation

enum RackVerify {
  static func generatePlan(manifest: RackPackManifestV1, macroRegion: String = "rack.macros") -> [String: Any] {
    var ops: [[String: Any]] = []

    for rack in manifest.racks {
      let trackHint = rack.targetTrack ?? guessTrackHint(rack: rack)

      if let hint = trackHint {
        ops.append([
          "id": "select_track_\(sanitize(rack.rackId))",
          "do": ["type":"click_ocr_match","region":"tracks.list","match":["text": hint, "mode":"contains","min_conf":0.75]],
          "post": [["type":"ui_text_contains","region":"tracks.list","text": hint, "min_conf": 0.70]],
          "retries": 2,
          "timeout_ms": 8000
        ])
      }

      ops.append([
        "id": "verify_macros_\(sanitize(rack.rackId))",
        "do": ["type":"sleep","ms":120],
        "post": rack.macroNames.map { ["type":"ui_text_contains","region": macroRegion, "text": $0, "min_conf": 0.65] },
        "retries": 2,
        "timeout_ms": 9000
      ])

      for (i, chk) in rack.verification.checks.enumerated() {
        var post: [[String: Any]] = []
        switch chk.type {
        case "ocr_contains_all":
          post = chk.tokens.map { ["type":"ui_text_contains","region": chk.region, "text": $0, "min_conf": chk.minConf] }
        case "ocr_contains_any":
          post = [["type":"ui_text_contains_any","region": chk.region, "tokens": chk.tokens, "min_conf": chk.minConf]]
        default:
          post = []
        }
        ops.append([
          "id": "verify_check_\(sanitize(rack.rackId))_\(i)",
          "do": ["type":"sleep","ms":80],
          "post": post,
          "retries": 1,
          "timeout_ms": 6000
        ])
      }
    }

    return [
      "schema_version": 1,
      "run_id": "rack_verify_v1",
      "mode": "apply",
      "targets": ["os":"macos","ableton":"12.3","plugin_format_preference":["au","vst3"]],
      "anchors": ["pack_id":"ableton12_3_default","min_score":0.9],
      "ops": ops
    ]
  }

  static func guessTrackHint(rack: RackPackManifestV1.Rack) -> String? {
    guard let toks = rack.expectedTokens else { return nil }
    let preferred = ["BassLead","Sub","MidGrowl","DrumBus","Vox"]
    for p in preferred {
      if toks.contains(where: { $0.caseInsensitiveCompare(p) == .orderedSame }) { return p }
    }
    if let first = toks.first, first.count <= 12 { return first }
    return nil
  }

  static func sanitize(_ s: String) -> String {
    s.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_").replacingOccurrences(of: " ", with: "_")
  }
}
