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

    ops += SaveDialogDriver.saveSheetOps(idPrefix: "save_", targetDir: outDir, fileName: fileName)

    return [
      "schema_version": 1,
      "run_id": "racks_export",
      "mode": "apply",
      "targets": ["os":"macos","ableton":"12.3"],
      "ops": ops
    ]
  }
}
