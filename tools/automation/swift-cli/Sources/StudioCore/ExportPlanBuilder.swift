import Foundation

enum ExportPlanBuilder {
  static func buildExportPlan(exportChord: String, filename: String) -> [String: Any] {
    return [
      "schema_version": 1,
      "run_id": "export_clip_v1",
      "mode": "apply",
      "targets": ["os":"macos","ableton":"12.3","plugin_format_preference":["au","vst3"]],
      "anchors": ["pack_id":"ableton12_3_default","min_score":0.9],
      "ops": [
        ["id":"export_trigger", "do":["type":"press_keys","keys":[exportChord]], "retries":1, "timeout_ms":3000],
        ["id":"export_wait", "do":["type":"sleep","ms":500], "retries":0, "timeout_ms":3000],
        ["id":"export_focus_filename",
         "do":["type":"click_anchor","anchor_id":"macos.open_dialog.filename_field","fallback_region":"os.file_dialog.filename_field"],
         "retries":2, "timeout_ms":8000],
        ["id":"export_select_all", "do":["type":"press_keys","keys":["CMD+A"]], "retries":1, "timeout_ms":2000],
        ["id":"export_type_filename", "do":["type":"type_text","text": filename], "retries":1, "timeout_ms":2000],
        ["id":"export_confirm", "do":["type":"press_keys","keys":["ENTER"]], "retries":1, "timeout_ms":3000],
        ["id":"export_no_modal", "do":["type":"sleep","ms":200], "post":[["type":"no_modal_dialog"]], "retries":1, "timeout_ms":6000]
      ]
    ]
  }
}
