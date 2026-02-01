import Foundation

enum RackInstall {
  /// Generates a v4 plan that instantiates racks by searching in Ableton Browser and inserting (double-click).
  /// Assumes racks are available in User Library and searchable by display_name.
  static func generateInstallPlan(manifest: RackPackManifestV1,
                                  macroRegion: String = "rack.macros",
                                  insertVerifyTokens: [String: String] = [:]) -> [String: Any] {
    var ops: [[String: Any]] = []

    for rack in manifest.racks {
      let track = RackVerify.guessTrackHint(rack: rack) ?? "Track"

      // 1) select track
      ops.append([
        "id": "install_select_track_\(RackVerify.sanitize(rack.rackId))",
        "do": ["type":"click_ocr_match","region":"tracks.list","match":["text": track, "mode":"contains","min_conf":0.75]],
        "post": [["type":"ui_text_contains","region":"tracks.list","text": track, "min_conf":0.70]],
        "retries": 2,
        "timeout_ms": 8000,
        "notes": "Select target track"
      ])

      // 2) search browser for rack display name and insert by double click
      ops.append([
        "id": "install_search_\(RackVerify.sanitize(rack.rackId))",
        "do": ["type":"search_browser","query": rack.displayName, "anchor_id":"ableton.browser.search_field", "fallback_region":"browser.search"],
        "post": [["type":"ui_text_contains","region":"browser.results","text": rack.displayName, "min_conf":0.65]],
        "retries": 2,
        "timeout_ms": 9000,
        "notes": "Search rack in Browser"
      ])

      ops.append([
        "id": "install_insert_\(RackVerify.sanitize(rack.rackId))",
        "do": ["type":"dblclick_ocr_match","region":"browser.results","match":["text": rack.displayName, "mode":"contains","min_conf":0.65]],
        "post": [
          ["type":"ui_text_contains","region":"rack.macros","text":"Energy","min_conf":0.60]
        ],
        "retries": 2,
        "timeout_ms": 12000,
        "notes": "Insert rack via Browser double-click"
      ])

      // 3) verify macro labels exist (ABI)
      ops.append([
        "id": "install_verify_macros_\(RackVerify.sanitize(rack.rackId))",
        "do": ["type":"sleep","ms":150],
        "post": rack.macroNames.map { ["type":"ui_text_contains","region": macroRegion,"text": $0,"min_conf":0.65] },
        "retries": 2,
        "timeout_ms": 10000
      ])
    }

    return [
      "schema_version": 1,
      "run_id": "rack_install_v1",
      "mode": "apply",
      "targets": ["os":"macos","ableton":"12.3","plugin_format_preference":["au","vst3"]],
      "anchors": ["pack_id":"ableton12_3_default","min_score":0.9],
      "ops": ops
    ]
  }
}
