import Foundation
import Yams

enum SonicTune {
  struct SweepSummary: Decodable {
    let suggestedSafeMaxPosition: Double
    enum CodingKeys: String, CodingKey { case suggestedSafeMaxPosition = "suggested_safe_max_position" }
  }
  struct SweepReceipt: Decodable {
    let macro: String
    let summary: SweepSummary
  }

  /// Applies a safe max clamp to all range[1] entries for a macro in a profile YAML.
  /// Expected YAML shape: macro_targets: <MacroName>: targets: - serum/ableton: { range: [min,max] }
  static func tuneProfile(profileYamlPath: String,
                          sweepReceiptPath: String,
                          outPath: String?) throws -> (outPath: String, receipt: SonicTuneReceiptV1) {

    let runId = RunContext.makeRunId()
    let ts = ISO8601DateFormatter().string(from: Date())

    // Load sweep receipt (v7.2)
    let sweepData = try Data(contentsOf: URL(fileURLWithPath: sweepReceiptPath))
    let sweep = try JSONDecoder().decode(SweepReceipt.self, from: sweepData)
    let macro = sweep.macro
    let suggested = sweep.summary.suggestedSafeMaxPosition

    // Load profile YAML
    let profileText = try String(contentsOfFile: profileYamlPath, encoding: .utf8)
    let yamlAny = try Yams.load(yaml: profileText)
    guard var root = yamlAny as? [String: Any] else {
      throw NSError(domain: "SonicTune", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid profile YAML"])
    }

    var changes: [SonicTuneChangeV1] = []
    var reasons: [String] = []
    var status = "pass"

    guard var macroTargets = root["macro_targets"] as? [String: Any],
          var macroBlock = macroTargets[macro] as? [String: Any],
          var targets = macroBlock["targets"] as? [Any] else {
      status = "fail"
      reasons.append("Profile missing macro_targets.\(macro).targets")
      let receipt = SonicTuneReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts,
                                       inputSweepReceipt: sweepReceiptPath, profileIn: profileYamlPath,
                                       profileOut: outPath ?? "", status: status, macro: macro,
                                       suggestedSafeMaxPosition: suggested, changes: [], reasons: reasons)
      return (outPath ?? "", receipt)
    }

    // Iterate targets and clamp any embedded range
    for (i, tAny) in targets.enumerated() {
      guard var t = tAny as? [String: Any] else { continue }

      // t has key "serum" or "ableton"
      for k in ["serum","ableton"] {
        if var block = t[k] as? [String: Any],
           let range = block["range"] as? [Any],
           range.count == 2,
           let lo = range[0] as? Double,
           let hi = range[1] as? Double {

          let newHi = min(hi, suggested)
          if newHi < hi {
            block["range"] = [lo, newHi]
            t[k] = block
            targets[i] = t
            changes.append(SonicTuneChangeV1(macro: macro,
                                             path: "macro_targets.\(macro).targets[\(i)].\(k).range",
                                             before: [lo, hi],
                                             after: [lo, newHi]))
          }
        }
      }
    }

    // Write updated YAML
    macroBlock["targets"] = targets
    macroTargets[macro] = macroBlock
    root["macro_targets"] = macroTargets

    let out = outPath ?? defaultOutPath(profileYamlPath: profileYamlPath)
    let dumped = try Yams.dump(object: root, sortKeys: true)
    try dumped.data(using: .utf8)?.write(to: URL(fileURLWithPath: out))

    if changes.isEmpty {
      status = "warn"
      reasons.append("No ranges changed (either already <= suggested_safe_max_position or no parsable ranges).")
    }

    let receipt = SonicTuneReceiptV1(schemaVersion: 1,
                                     runId: runId,
                                     timestamp: ts,
                                     inputSweepReceipt: sweepReceiptPath,
                                     profileIn: profileYamlPath,
                                     profileOut: out,
                                     status: status,
                                     macro: macro,
                                     suggestedSafeMaxPosition: suggested,
                                     changes: changes,
                                     reasons: reasons)
    return (out, receipt)
  }

  private static func defaultOutPath(profileYamlPath: String) -> String {
    let u = URL(fileURLWithPath: profileYamlPath)
    let base = u.deletingPathExtension().lastPathComponent
    let dir = u.deletingLastPathComponent()
    return dir.appendingPathComponent("\(base).tuned.yaml").path
  }
}
