import Foundation

struct SimpleInventoryIndex {
  let normNames: Set<String>
  init(inventory: InventoryDoc) {
    var s = Set<String>()
    for it in inventory.items {
      s.insert(StudioNormV1.normNameV1(it.displayName))
    }
    normNames = s
  }
  func has(_ name: String) -> Bool {
    let n = StudioNormV1.normNameV1(name)
    return normNames.contains(where: { $0.contains(n) || n.contains($0) })
  }
}

enum RackRecommend {
  struct Recommendation: Codable {
    let rackId: String
    let missing: [String]
    let suggestions: [String]
  }

  static func recommend(manifest: RackPackManifestV1, inventory: InventoryDoc, recsPath: String?) -> [Recommendation] {
    let idx = SimpleInventoryIndex(inventory: inventory)
    // load recommendations mapping if present (best-effort)
    var tagToSug: [String: [String]] = [:]
    if let p = recsPath, FileManager.default.fileExists(atPath: p),
       let data = try? Data(contentsOf: URL(fileURLWithPath: p)),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let tags = obj["tags"] as? [String: Any] {
      for (k, v) in tags {
        if let m = v as? [String: Any], let sugs = m["suggestions"] as? [[String: Any]] {
          tagToSug[k] = sugs.compactMap { $0["name"] as? String }
        }
      }
    }

    var out: [Recommendation] = []
    for r in manifest.racks {
      var missing: [String] = []
      for req in r.requires where req.optional == false {
        if !idx.has(req.name) { missing.append(req.name) }
      }
      var suggestions: [String] = []
      if missing.contains(where: { StudioNormV1.normNameV1($0).contains("serum") }) {
        suggestions += (tagToSug["synth"] ?? ["Serum 2 (AU)","Wavetable"])
      }
      if missing.contains(where: { StudioNormV1.normNameV1($0).contains("utility") }) {
        suggestions += (tagToSug["sub_safety"] ?? ["Utility","Limiter"])
      }
      out.append(.init(rackId: r.rackId, missing: missing, suggestions: Array(Set(suggestions))))
    }
    return out
  }
}
