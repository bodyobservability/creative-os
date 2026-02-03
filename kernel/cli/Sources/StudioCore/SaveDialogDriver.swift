import Foundation

enum SaveDialogDriver {
  static func saveSheetOps(idPrefix: String, targetDir: String, fileName: String) -> [[String: Any]] {
    return [
      [
        "id": "\(idPrefix)wait_sheet",
        "do": ["type":"sleep","ms":350],
        "retries": 0,
        "timeout_ms": 2000
      ],
      [
        "id": "\(idPrefix)focus_filename_pre",
        "do": ["type":"click_anchor","anchor_id":"macos.open_dialog.filename_field","fallback_region":"os.file_dialog.filename_field"],
        "retries": 2,
        "timeout_ms": 8000
      ],
      [
        "id": "\(idPrefix)goto_folder",
        "do": ["type":"press_keys","keys":["CMD+SHIFT+G"]],
        "retries": 1,
        "timeout_ms": 2000,
        "notes": "macOS save sheet: Go to folder"
      ],
      [
        "id": "\(idPrefix)type_folder",
        "do": ["type":"type_text","text": targetDir],
        "retries": 1,
        "timeout_ms": 2000
      ],
      [
        "id": "\(idPrefix)confirm_folder",
        "do": ["type":"press_keys","keys":["ENTER"]],
        "retries": 1,
        "timeout_ms": 3000
      ],
      [
        "id": "\(idPrefix)focus_filename",
        "do": ["type":"click_anchor","anchor_id":"macos.open_dialog.filename_field","fallback_region":"os.file_dialog.filename_field"],
        "retries": 2,
        "timeout_ms": 8000
      ],
      [
        "id": "\(idPrefix)select_all_name",
        "do": ["type":"press_keys","keys":["CMD+A"]],
        "retries": 1,
        "timeout_ms": 2000
      ],
      [
        "id": "\(idPrefix)type_filename",
        "do": ["type":"type_text","text": fileName],
        "retries": 1,
        "timeout_ms": 2000
      ],
      [
        "id": "\(idPrefix)confirm_save",
        "do": ["type":"press_keys","keys":["ENTER"]],
        "retries": 1,
        "timeout_ms": 5000
      ],
      [
        "id": "\(idPrefix)no_modal",
        "do": ["type":"sleep","ms":250],
        "post": [["type":"no_modal_dialog"]],
        "retries": 1,
        "timeout_ms": 6000
      ]
    ]
  }
}
