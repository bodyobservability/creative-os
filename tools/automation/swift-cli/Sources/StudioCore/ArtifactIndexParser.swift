import Foundation

struct ArtifactIndexCounts {
  let missing: Int
  let placeholder: Int
}

struct ArtifactIndexParser {
  static func parseCounts(path: String) -> ArtifactIndexCounts? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let arts = obj["artifacts"] as? [[String: Any]] else {
      return nil
    }
    var missing = 0
    var placeholder = 0
    for a in arts {
      if let st = a["status"] as? [String: Any],
         let state = st["state"] as? String {
        if state == "missing" { missing += 1 }
        if state == "placeholder" { placeholder += 1 }
      }
    }
    return ArtifactIndexCounts(missing: missing, placeholder: placeholder)
  }
}
