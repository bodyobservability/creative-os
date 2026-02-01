import Foundation
import CoreGraphics

// Drop-in extensions for v4.3/v4.3.1 actions + asserts.
// Works in SwiftPM builds without OpenCV: click_anchor falls back to region centers.
// In OpenCV-enabled Xcode builds, you should replace clickAnchor() to use template matching.

extension ApplyRunner {

  // MARK: - click_anchor action

  func performClickAnchor(anchorId: String, fallbackRegion: String?, opId: String, attempt: Int) async throws {
    traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "action", name: "click_anchor",
                       details: ["anchor_id": anchorId, "fallback_region": fallbackRegion ?? "nil"])

    if let rid = fallbackRegion {
      try await clickRegionCenter(regionId: rid)
      return
    }

    // best-effort fallbacks by anchor prefix
    if anchorId.hasPrefix("serum.") {
      try await clickRegionCenter(regionId: "plugin.window")
      return
    }
    if anchorId.hasPrefix("macos.open_dialog.") {
      try await clickRegionCenter(regionId: "os.file_dialog")
      return
    }
    if anchorId.hasPrefix("ableton.") {
      // try browser.search as a safe default
      try await clickRegionCenter(regionId: "browser.search")
      return
    }

    throw NSError(domain: "ApplyRunner", code: 31, userInfo: [NSLocalizedDescriptionKey: "click_anchor failed for \(anchorId)"])
  }

  // MARK: - open_plugin_window action

  func performOpenPluginWindow(pluginName: String, deviceChainText: String, opId: String, attempt: Int) async throws {
    // 1) focus the plugin device in the chain
    try await clickOCR(regionId: "device.chain",
                       match: OCRMatchSpec(text: deviceChainText, mode: "contains", minConf: 0.70),
                       double: false,
                       opId: opId,
                       attempt: attempt)

    // 2) click the Ableton device header button (anchor), fallback to controls region center
    try await performClickAnchor(anchorId: "ableton.device_header.plugin_window_button",
                                 fallbackRegion: "device.chain.controls",
                                 opId: opId,
                                 attempt: attempt)

    try actuator.sleepMs(200)

    traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "note", name: "open_plugin_window_done",
                       details: ["plugin": pluginName])
  }

  // MARK: - Assert: ui_anchor_present

  func assertUiAnchorPresent(anchorId: String, minScore: Double?, opId: String, attempt: Int) async throws -> Bool {
    // SwiftPM fallback:
    // - For serum.window.signature, verify OCR token "Serum" appears in plugin.window.
    // - For macOS dialog anchors, verify OCR token "Open" or "Name" in relevant region.
    if anchorId == "serum.window.signature" {
      return try await regionContainsText(regionId: "plugin.window", text: "Serum", minConf: 0.65, opId: opId, attempt: attempt)
    }
    if anchorId == "macos.open_dialog.open_button" {
      return try await regionContainsText(regionId: "os.file_dialog.open_button", text: "Open", minConf: 0.60, opId: opId, attempt: attempt)
    }
    if anchorId == "macos.open_dialog.filename_field" {
      return try await regionContainsText(regionId: "os.file_dialog.filename_field", text: "Name", minConf: 0.55, opId: opId, attempt: attempt)
    }
    // Without OpenCV enabled, arbitrary anchors can't be validated reliably.
    _ = minScore
    traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "assert", name: "ui_anchor_present",
                       details: ["anchor_id": anchorId, "result": "unsupported_in_swiftpm"])
    return false
  }

  // MARK: - Assert: plugin_window_open

  func assertPluginWindowOpen(pluginName: String, opId: String, attempt: Int) async throws -> Bool {
    return try await regionContainsText(regionId: "plugin.window", text: pluginName, minConf: 0.65, opId: opId, attempt: attempt)
  }
}
