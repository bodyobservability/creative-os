import Foundation

enum PerformanceSetPlanBuilder {
  /// Save-As the current Ableton set to a specific repo path.
  /// Uses macOS save sheet: Cmd+Shift+G (Go to Folder) + filename set + Enter.
  static func buildPerformanceSetExportPlan(targetDir: String, fileName: String) -> [String: Any] {
    let ops: [[String: Any]] = [
      ["id":"save_as", "do":["type":"press_keys","keys":["CMD+SHIFT+S"]], "retries":1, "timeout_ms":3000],
      ["id":"wait_sheet", "do":["type":"sleep","ms":500], "retries":0, "timeout_ms":2000],

      ["id":"goto_folder", "do":["type":"press_keys","keys":["CMD+SHIFT+G"]], "retries":1, "timeout_ms":2000],
      ["id":"type_folder", "do":["type":"type_text","text": targetDir], "retries":1, "timeout_ms":2000],
      ["id":"confirm_folder", "do":["type":"press_keys","keys":["ENTER"]], "retries":1, "timeout_ms":3000],

      ["id":"focus_filename", "do":["type":"click_anchor","anchor_id":"macos.open_dialog.filename_field","fallback_region":"os.file_dialog.filename_field"], "retries":2, "timeout_ms":8000],
      ["id":"select_all", "do":["type":"press_keys","keys":["CMD+A"]], "retries":1, "timeout_ms":2000],
      ["id":"type_name", "do":["type":"type_text","text": fileName], "retries":1, "timeout_ms":2000],
      ["id":"confirm_save", "do":["type":"press_keys","keys":["ENTER"]], "retries":1, "timeout_ms":6000],

      ["id":"no_modal", "do":["type":"sleep","ms":250], "post":[["type":"no_modal_dialog"]], "retries":1, "timeout_ms":6000]
    ]

    return [
      "schema_version": 1,
      "run_id": "performance_set_export_v9_5_2",
      "mode": "apply",
      "targets": ["os":"macos","ableton":"12.3"],
      "ops": ops
    ]
  }
}
