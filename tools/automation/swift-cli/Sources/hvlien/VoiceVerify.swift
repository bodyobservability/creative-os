import Foundation
import Yams

enum VoiceVerify {
  struct Profile {
    let tracks: [String]
    let voxDevices: [String]
    let serumDevices: [String]
  }

  static func generatePlan(abiPath: String,
                           outPath: String,
                           includeMacroNameOCR: Bool,
                           macroRegionId: String,
                           profile: Profile = .init(tracks: ["Vox","SerumLead"],
                                                    voxDevices: ["EQ Eight","Compressor","Limiter","Utility"],
                                                    serumDevices: ["Serum","EQ Eight","Utility","Limiter"])) throws {
    let abiText = try String(contentsOfFile: abiPath, encoding: .utf8)
    let loaded = try Yams.load(yaml: abiText)
    guard let root = loaded as? [String: Any] else {
      throw NSError(domain: "VoiceVerify", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid ABI YAML"])
    }

    // Extract macro names from ABI
    var macroNames: [String] = []
    if let macros = root["macros"] as? [Any] {
      for m in macros {
        if let mm = m as? [String: Any], let name = mm["name"] as? String {
          macroNames.append(name)
        }
      }
    }

    var ops: [[String: Any]] = []

    // Track presence
    ops.append([
      "id": "verify_tracks_present",
      "do": ["type":"sleep","ms":100],
      "post": profile.tracks.map { ["type":"ui_text_contains","region":"tracks.list","text": $0, "min_conf": 0.70] },
      "retries": 1,
      "timeout_ms": 5000
    ])

    // Vox chain
    ops.append([
      "id": "verify_vox_chain",
      "do": ["type":"click_ocr_match","region":"tracks.list","match":["text":"Vox","mode":"contains","min_conf":0.75]],
      "post": profile.voxDevices.map { ["type":"ui_text_contains","region":"device.chain","text": $0, "min_conf": 0.70] },
      "retries": 2,
      "timeout_ms": 8000
    ])

    // Serum chain
    ops.append([
      "id": "verify_serum_chain",
      "do": ["type":"click_ocr_match","region":"tracks.list","match":["text":"Serum","mode":"contains","min_conf":0.75]],
      "post": profile.serumDevices.map { ["type":"ui_text_contains","region":"device.chain","text": $0, "min_conf": 0.65] },
      "retries": 2,
      "timeout_ms": 8000
    ])

    // Macro name OCR checks (optional)
    if includeMacroNameOCR && !macroNames.isEmpty {
      ops.append([
        "id": "verify_macro_names",
        "do": ["type":"sleep","ms":120],
        "post": macroNames.map { ["type":"ui_text_contains","region": macroRegionId, "text": $0, "min_conf": 0.65] },
        "retries": 2,
        "timeout_ms": 8000,
        "notes": "Requires regions.v1.json to define a rack macro label region (default: rack.macros)."
      ])
    }

    let plan: [String: Any] = [
      "schema_version": 1,
      "run_id": "verify_abi_v1_generated",
      "mode": "apply",
      "targets": ["os":"macos","ableton":"12.3","plugin_format_preference":["au","vst3"]],
      "anchors": ["pack_id":"ableton12_3_default","min_score":0.9],
      "ops": ops
    ]

    let data = try JSONSerialization.data(withJSONObject: plan, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: outPath))
  }
}
