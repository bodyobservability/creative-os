import Foundation

enum PerformanceSetPlanBuilder {
  /// Save-As the current Ableton set to a specific repo path.
  /// Uses macOS save sheet: Cmd+Shift+G (Go to Folder) + filename set + Enter.
  static func buildPerformanceSetExportPlan(targetDir: String, fileName: String) -> [String: Any] {
    var ops: [[String: Any]] = [
      ["id":"save_as", "do":["type":"press_keys","keys":["CMD+SHIFT+S"]], "retries":1, "timeout_ms":3000]
    ]
    ops += SaveDialogDriver.saveSheetOps(idPrefix: "save_", targetDir: targetDir, fileName: fileName)

    return [
      "schema_version": 1,
      "run_id": "performance_set_export_v9_5_2",
      "mode": "apply",
      "targets": ["os":"macos","ableton":"12.3"],
      "ops": ops
    ]
  }
}
