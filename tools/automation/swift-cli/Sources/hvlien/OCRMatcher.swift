import Foundation

enum OCRMatcher {
  struct Match {
    let line: OCRLine
    let score: Double
  }

  static func bestMatch(lines: [OCRLine], target: String, mode: String, minConf: Double) -> Match? {
    let t = HVLIENNormV1.normNameV1(target)
    if t == "__invalid__" { return nil }

    var best: Match? = nil
    for ln in lines {
      if ln.confidence < minConf { continue }
      let s = HVLIENNormV1.normNameV1(ln.text)
      if s == "__invalid__" { continue }
      let score: Double
      switch mode {
      case "exact":
        score = (s == t) ? 1.0 : 0.0
      case "contains":
        score = s.contains(t) ? 0.95 : tokenOverlap(a: t, b: s)
      case "fuzzy":
        score = tokenOverlap(a: t, b: s)
      default:
        score = s.contains(t) ? 0.95 : tokenOverlap(a: t, b: s)
      }
      if score <= 0 { continue }
      if best == nil || score > best!.score { best = Match(line: ln, score: score) }
    }
    return best
  }

  private static func tokenOverlap(a: String, b: String) -> Double {
    let ta = Set(a.split(separator: " ").map(String.init))
    let tb = Set(b.split(separator: " ").map(String.init))
    if ta.isEmpty || tb.isEmpty { return 0.0 }
    let inter = ta.intersection(tb).count
    let denom = max(ta.count, tb.count)
    return Double(inter) / Double(denom)
  }
}
