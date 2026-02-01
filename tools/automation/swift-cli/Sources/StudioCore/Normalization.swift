import Foundation
import CryptoKit

enum StudioNormV1 {
  private static let ws = try! NSRegularExpression(pattern: #"\s+"#)
  private static let bulletDash: Set<Character> = ["\u{00B7}","\u{2022}","\u{2219}","\u{2014}","\u{2013}"]

  static func normNameV1(_ sIn: String?) -> String {
    guard var s = sIn else { return "__invalid__" }
    s = s.precomposedStringWithCompatibilityMapping
    s = s.trimmingCharacters(in: .whitespacesAndNewlines)
    s = s.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    s = collapseWS(s)
    var scalars = String.UnicodeScalarView()
    for u in s.unicodeScalars {
      let ch = Character(u)
      if bulletDash.contains(ch) { scalars.append(UnicodeScalar(0x20)!) } else { scalars.append(u) }
    }
    s = collapseWS(String(scalars))
    return s.isEmpty ? "__invalid__" : s
  }

  static func vendorGroupV1(_ vendor: String?) -> String {
    guard var v = vendor, !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return "unknown" }
    v = v.precomposedStringWithCompatibilityMapping
    v = v.trimmingCharacters(in: .whitespacesAndNewlines)
    v = v.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    v = collapseWS(v)
    let alias: [String: String] = ["ableton ag":"ableton","ableton":"ableton","xfer records":"xfer","xfer":"xfer"]
    return alias[v] ?? v
  }

  static func dedupeKeyV1(kind: String, format: String?, vendor: String?, norm: String) -> String {
    "\(kind)|\(format ?? "null")|\(vendorGroupV1(vendor))|\(norm)"
  }

  static func stableKeyV1(kind: String, format: String?, vendor: String?, norm: String) -> String {
    let base = dedupeKeyV1(kind: kind, format: format, vendor: vendor, norm: norm)
    let dig = SHA256.hash(data: Data(base.utf8))
    return dig.map { String(format: "%02x", $0) }.joined()
  }

  private static func collapseWS(_ s: String) -> String {
    let ns = s as NSString
    let r = NSRange(location: 0, length: ns.length)
    return ws.stringByReplacingMatches(in: s, options: [], range: r, withTemplate: " ").trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

enum ConfidenceGateV1 {
  static let admit = 0.70
  static let corroborateMin = 0.55
}
