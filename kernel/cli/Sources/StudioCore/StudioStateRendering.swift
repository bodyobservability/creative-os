import Foundation

struct StationBarRender {
  static func renderLine(label: String, gates: [ReadinessGate], next: String?, showSpace: Bool = true) -> String {
    let tag = label.padding(toLength: 10, withPad: " ", startingAt: 0)
    let tokens = gates.map { gateToken($0) }.joined(separator: "  ")
    let nextText = next ?? "—"
    let space = showSpace ? "   [SPACE]" : ""
    return "\(tag)  \(tokens)    next: \(nextText)\(space)"
  }

  static func gateToken(_ gate: ReadinessGate) -> String {
    let mark: String
    switch gate.status {
    case .pass: mark = "▣"
    case .pending: mark = "▢"
    case .warn: mark = "!"
    case .fail: mark = "×"
    }
    if gate.key == "F", let detail = gate.detail, detail.contains("missing=") {
      let count = detail
        .split(separator: ",")
        .compactMap { part -> Int? in
          let kv = part.split(separator: "=")
          if kv.count == 2 { return Int(kv[1].trimmingCharacters(in: .whitespaces)) }
          return nil
        }
        .reduce(0, +)
      if count > 0 { return "F\(mark)(\(count))" }
    }
    return "\(gate.key)\(mark)"
  }
}
