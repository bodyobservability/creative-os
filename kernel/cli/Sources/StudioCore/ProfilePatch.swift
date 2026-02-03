import Foundation
import Yams

enum ProfilePatch {
  struct Change {
    let path: String
    let before: [Double]
    let after: [Double]
  }

  static func emit(profileIn: String, tunedIn: String, patchOut: String?) throws -> (patchPath: String, receipt: ProfilePatchReceiptV1) {
    let runId = RunContext.makeRunId()
    let ts = ISO8601DateFormatter().string(from: Date())

    let aText = try String(contentsOfFile: profileIn, encoding: .utf8)
    let bText = try String(contentsOfFile: tunedIn, encoding: .utf8)
    let aAny = try Yams.load(yaml: aText)
    let bAny = try Yams.load(yaml: bText)
    guard let a = aAny as? [String: Any], let b = bAny as? [String: Any] else {
      let r = ProfilePatchReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, profileIn: profileIn, tunedIn: tunedIn,
                                    status: "fail", patchPath: "", changes: [], reasons: ["invalid_yaml"])
      return ("", r)
    }

    let changes = diffRanges(a: a, b: b)

    var status = "pass"
    var reasons: [String] = []
    if changes.isEmpty { status = "warn"; reasons.append("no_changes_detected") }

    let runDir = URL(fileURLWithPath: RepoPaths.defaultRunsDir()).appendingPathComponent(runId, isDirectory: true)
    try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

    let patchPath = patchOut ?? runDir.appendingPathComponent("profile_patch.v1.json").path
    let patchObj: [String: Any] = [
      "schema_version": 1,
      "profile_in": profileIn,
      "tuned_in": tunedIn,
      "changes": changes.map { ["path": $0.path, "before": $0.before, "after": $0.after] }
    ]
    let data = try JSONSerialization.data(withJSONObject: patchObj, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: patchPath))

    let receipt = ProfilePatchReceiptV1(schemaVersion: 1, runId: runId, timestamp: ts, profileIn: profileIn, tunedIn: tunedIn,
                                        status: status, patchPath: patchPath,
                                        changes: changes.map { ProfilePatchChangeV1(path: $0.path, before: $0.before, after: $0.after) },
                                        reasons: reasons)
    return (patchPath, receipt)
  }

  private static func diffRanges(a: [String: Any], b: [String: Any]) -> [Change] {
    // Walk macro_targets.*.targets[*].(serum|ableton).range
    func extract(_ root: [String: Any]) -> [String: [Double]] {
      var out: [String: [Double]] = [:]
      guard let mt = root["macro_targets"] as? [String: Any] else { return out }
      for (macro, v) in mt {
        guard let block = v as? [String: Any], let targets = block["targets"] as? [Any] else { continue }
        for (i, tAny) in targets.enumerated() {
          guard let t = tAny as? [String: Any] else { continue }
          for k in ["serum","ableton"] {
            if let kk = t[k] as? [String: Any], let r = kk["range"] as? [Any], r.count == 2,
               let lo = r[0] as? Double, let hi = r[1] as? Double {
              out["macro_targets.\(macro).targets[\(i)].\(k).range"] = [lo, hi]
            }
          }
        }
      }
      return out
    }

    let ea = extract(a)
    let eb = extract(b)
    var changes: [Change] = []
    for (path, before) in ea {
      if let after = eb[path], before != after {
        changes.append(Change(path: path, before: before, after: after))
      }
    }
    return changes.sorted { $0.path < $1.path }
  }
}
