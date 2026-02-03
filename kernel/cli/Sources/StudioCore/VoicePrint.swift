import Foundation
import Yams

enum VoicePrint {
  static func renderMarkdown(scriptPath: String,
                             anchorsPack: String?,
                             displayProfile: String?,
                             abletonVersion: String?,
                             abletonTheme: String?,
                             outPath: String?) throws -> String {

    let yamlText = try String(contentsOfFile: scriptPath, encoding: .utf8)
    let loaded = try Yams.load(yaml: yamlText)
    guard let root = loaded as? [String: Any] else {
      throw NSError(domain: "VoicePrint", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid YAML root"])
    }

    let verifyPlan = WubDefaults.profileSpecPath("voice/verify/verify_abi.plan.v1.json")
    let scriptName = (root["name"] as? String) ?? URL(fileURLWithPath: scriptPath).lastPathComponent
    let goal = (root["goal"] as? String) ?? ""
    let assumptions = (root["assumptions"] as? [String: Any]) ?? [:]
    let steps = (root["steps"] as? [Any]) ?? []

    func fmtAssumptions(_ a: [String: Any], indent: String = "") -> String {
      var lines: [String] = []
      for k in a.keys.sorted() {
        if let v = a[k] as? [String: Any] {
          lines.append("\(indent)- **\(k)**:")
          lines.append(fmtAssumptions(v, indent: indent + "  "))
        } else {
          lines.append("\(indent)- **\(k)**: \(String(describing: a[k]!))")
        }
      }
      return lines.joined(separator: "\n")
    }

    func fmtStep(_ s: Any, idx: Int) -> String {
      if let m = s as? [String: Any] {
        if let section = m["section"] as? String { return "\(idx). **SECTION** — \(section)" }
        if let say = m["say"] as? String { return "\(idx). **SAY**: \(say)" }
        if let dic = m["dictate"] as? String { return "\(idx). **DICTATE**: \(dic)" }
        if let rename = m["rename_macros"] as? [String: Any] {
          var out = ["\(idx). **RENAME MACROS**:"]
          for k in rename.keys.sorted() { out.append("   - Macro \(k): \(rename[k]!)") }
          return out.joined(separator: "\n")
        }
        if let map = m["map"] as? [String: Any] {
          let macro = map["macro"].map { "\($0)" } ?? "?"
          let name = map["name"].map { "\($0)" } ?? ""
          let intent = map["intent"].map { "\($0)" } ?? ""
          return "\(idx). **MAP**: Macro \(macro) \(name) → \(intent)"
        }
        if let verify = m["verify"] as? [String: Any] {
          return "\(idx). **VERIFY**: \(verify)"
        }
      }
      return "\(idx). \(String(describing: s))"
    }

    let md = """
# Voice Compile Card

**Script:** \(scriptName)  
**Display Profile:** \(displayProfile ?? "unspecified")  
**Ableton:** \(abletonVersion ?? "unspecified") / Theme: \(abletonTheme ?? "unspecified")  
**Goal:** \(goal)

---

## Assumptions
\(assumptions.isEmpty ? "- (none)" : fmtAssumptions(assumptions))

---

## Steps
\(steps.enumerated().map { fmtStep($0.element, idx: $0.offset + 1) }.joined(separator: "\n"))

---

## After the voice compile (v4 verification)
Run:

```bash
wub sweep --modal-test detect --anchors-pack \(anchorsPack ?? "<anchors_pack>") --allow-ocr-fallback
wub apply --plan \(verifyPlan) --anchors-pack \(anchorsPack ?? "<anchors_pack>")
```

Artifacts:
- \(RepoPaths.defaultRunsDir())/<run_id>/receipt.v1.json
- \(RepoPaths.defaultRunsDir())/<run_id>/trace.v1.json
- \(RepoPaths.defaultRunsDir())/<run_id>/failures/...

---

## Notes
- Voice Control is compile-time only.
- Macro ABI names are canonical; do not rename.
"""

    if let outPath = outPath {
      try md.data(using: .utf8)?.write(to: URL(fileURLWithPath: outPath))
    }
    return md
  }
}
