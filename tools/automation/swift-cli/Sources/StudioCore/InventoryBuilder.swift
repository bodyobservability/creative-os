import Foundation

struct InventorySighting {
  let displayName: String
  let kind: String
  let format: String?
  let vendor: String?
  let tags: [String]
  let sample: EvidenceSample
}

final class InventoryBuilderV1 {
  private var keys: Set<String> = []
  private var raw: [InventoryItem] = []

  func ingest(_ s: InventorySighting) {
    let norm = StudioNormV1.normNameV1(s.displayName)
    guard norm != "__invalid__" else { return }
    let key = StudioNormV1.dedupeKeyV1(kind: s.kind, format: s.format, vendor: s.vendor, norm: norm)
    let conf = s.sample.confidence

    if keys.contains(key) {
      if conf < ConfidenceGateV1.corroborateMin { return }
    } else {
      if conf < ConfidenceGateV1.admit { return }
      keys.insert(key)
    }

    let stable = StudioNormV1.stableKeyV1(kind: s.kind, format: s.format, vendor: s.vendor, norm: norm)
    raw.append(InventoryItem(
      id: UUID().uuidString,
      stableKey: stable,
      displayName: s.displayName,
      normName: norm,
      kind: s.kind,
      format: s.format,
      vendor: s.vendor,
      tags: s.tags.map { StudioNormV1.normNameV1($0) }.filter { $0 != "__invalid__" },
      browserPath: [],
      evidence: Evidence(seenCount: 1, bestConfidence: conf, samples: [s.sample])
    ))
  }

  func finalize() -> [InventoryItem] {
    let merged = MergeV1.merge(raw, maxSamples: 10)
    return merged.map { it in
      var o = it
      o.stableKey = StudioNormV1.stableKeyV1(kind: it.kind, format: it.format, vendor: it.vendor, norm: it.normName)
      return o
    }
  }
}
