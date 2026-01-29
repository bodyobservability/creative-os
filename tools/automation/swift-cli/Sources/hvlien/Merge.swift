import Foundation

enum MergeV1 {
  static func merge(_ items: [InventoryItem], maxSamples: Int = 10) -> [InventoryItem] {
    var buckets: [String: [InventoryItem]] = [:]
    for it in items {
      let key = HVLIENNormV1.dedupeKeyV1(kind: it.kind, format: it.format, vendor: it.vendor, norm: it.normName)
      buckets[key, default: []].append(it)
    }
    var out: [InventoryItem] = []
    for (_, g) in buckets {
      guard var m = g.first else { continue }
      // pick best display name by confidence
      var bestName = m.displayName
      var bestConf = (m.evidence.bestConfidence ?? 0)
      for it in g.dropFirst() {
        let c = it.evidence.bestConfidence ?? it.evidence.samples.map(\.confidence).max() ?? 0
        if c > bestConf || (c == bestConf && it.displayName.count > bestName.count) {
          bestName = it.displayName; bestConf = c
        }
      }
      m.displayName = bestName
      m.normName = HVLIENNormV1.normNameV1(bestName)
      // union tags, samples
      var tagSet = Set<String>(m.tags)
      var samples: [EvidenceSample] = []
      var seenCount = 0
      for it in g {
        tagSet.formUnion(it.tags)
        samples.append(contentsOf: it.evidence.samples)
        seenCount += it.evidence.seenCount ?? it.evidence.samples.count
      }
      samples.sort { $0.confidence > $1.confidence }
      m.tags = tagSet.sorted()
      m.evidence = Evidence(seenCount: seenCount, bestConfidence: samples.first?.confidence, samples: Array(samples.prefix(maxSamples)))
      out.append(m)
    }
    return out
  }
}
