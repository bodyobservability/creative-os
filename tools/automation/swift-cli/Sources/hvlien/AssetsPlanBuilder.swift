import Foundation

enum AssetsPlanBuilder {
  /// Build a v4 apply plan to:
  /// - select track
  /// - select rack device by OCR
  /// - save preset (Cmd+S)
  /// - macOS save sheet: go to folder, set filename, confirm
  ///
  /// Assumptions:
  /// - Ableton is frontmost
  /// - Rack is visible in device chain and searchable by `rackName`
  /// - macOS save sheet supports Cmd+Shift+G (Go to Folder)
  /// - regions include: tracks.list, device.chain, os.file_dialog.filename_field
  static func buildRackExportPlan(trackName: String?, rackName: String, outDir: String, fileName: String) -> [String: Any] {
    var ops: [[String: Any]] = []

    if let tn = trackName, !tn.isEmpty {
      ops.append([
        "id": "select_track",
        "do": ["type":"click_ocr_match","region":"tracks.list","match":["text": tn, "mode":"contains","min_conf":0.75]],
        "post": [["type":"ui_text_contains","region":"tracks.list","text": tn, "min_conf":0.70]],
        "retries": 2,
        "timeout_ms": 8000
      ])
    }

    // Click rack in device chain
    ops.append([
      "id": "select_rack",
      "do": ["type":"click_ocr_match","region":"device.chain","match":["text": rackName, "mode":"contains","min_conf":0.65]],
      "retries": 2,
      "timeout_ms": 9000,
      "notes": "If rackName OCR differs, adjust to a stable token or update manifest display_name."
    ])

    // Save preset
    ops.append([
      "id": "cmd_s_save",
      "do": ["type":"press_keys","keys":["CMD+S"]],
      "retries": 1,
      "timeout_ms": 3000
    ])

    // Go to folder (Cmd+Shift+G) -> type outDir -> Enter
    ops.append([
      "id": "goto_folder",
      "do": ["type":"press_keys","keys":["CMD+SHIFT+G"]],
      "retries": 1,
      "timeout_ms": 2000,
      "notes": "macOS save sheet: Go to folder"
    ])
    ops.append([
      "id": "type_folder",
      "do": ["type":"type_text","text": outDir],
      "retries": 1,
      "timeout_ms": 2000
    ])
    ops.append([
      "id": "confirm_folder",
      "do": ["type":"press_keys","keys":["ENTER"]],
      "retries": 1,
      "timeout_ms": 3000
    ])

    // Focus filename field via anchor if available, else region click
    ops.append([
      "id": "focus_filename",
      "do": ["type":"click_anchor","anchor_id":"macos.open_dialog.filename_field","fallback_region":"os.file_dialog.filename_field"],
      "retries": 2,
      "timeout_ms": 8000
    ])
    ops.append([
      "id": "select_all_name",
      "do": ["type":"press_keys","keys":["CMD+A"]],
      "retries": 1,
      "timeout_ms": 2000
    ])
    ops.append([
      "id": "type_filename",
      "do": ["type":"type_text","text": fileName],
      "retries": 1,
      "timeout_ms": 2000
    ])
    ops.append([
      "id": "confirm_save",
      "do": ["type":"press_keys","keys":["ENTER"]],
      "retries": 1,
      "timeout_ms": 5000
    ])

    // Modal guard postcheck (optional)
    ops.append([
      "id": "no_modal",
      "do": ["type":"sleep","ms":250],
      "post": [["type":"no_modal_dialog"]],
      "retries": 1,
      "timeout_ms": 6000
    ])

    return [
      "schema_version": 1,
      "run_id": "racks_export_v9_5_1",
      "mode": "apply",
      "targets": ["os":"macos","ableton":"12.3"],
      "ops": ops
    ]
  }
}
