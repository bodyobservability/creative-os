import Foundation
import Yams

enum ExpectedArtifactsParser {
  /// Reads known export specs under shared/specs/profiles/<active_profile>/assets/export/ and produces expected artifact paths + thresholds.
  /// v1.8.2: expands racks_export expected artifacts using rack_pack_manifest display names.
  static func parseAll(defaultDir: String = WubDefaults.profileSpecPath("assets/export"),
                       rackManifestPath: String = WubDefaults.profileSpecPath("library/racks/rack_pack_manifest.v1.json")) throws -> [ExpectedArtifactV1] {
    let fm = FileManager.default
    guard fm.fileExists(atPath: defaultDir) else { return [] }
    let files = try fm.contentsOfDirectory(atPath: defaultDir).filter { $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") }
    var out: [ExpectedArtifactV1] = []

    // Preload rack manifest if present
    var rackNames: [String] = []
    if fm.fileExists(atPath: rackManifestPath) {
      if let data = try? Data(contentsOf: URL(fileURLWithPath: rackManifestPath)),
         let mf = try? JSONDecoder().decode(RackPackManifestV1.self, from: data) {
        rackNames = mf.racks.map { $0.displayName }.sorted()
      }
    }

    for f in files {
      let p = URL(fileURLWithPath: defaultDir).appendingPathComponent(f).path
      if let items = try parseOne(path: p, rackNames: rackNames) { out.append(contentsOf: items) }
    }
    return out
  }

  private static func parseOne(path: String, rackNames: [String]) throws -> [ExpectedArtifactV1]? {
    let text = try String(contentsOfFile: path, encoding: .utf8)
    guard let root = try Yams.load(yaml: text) as? [String: Any] else { return nil }
    guard let job = root["job"] as? String else { return nil }
    let ver = root["verification"] as? [String: Any]
    let minBytes = ver?["min_bytes"] as? Int
    let warnBytes = ver?["warn_if_bytes_below"] as? Int

    switch job {
    case "racks_export":
      let outDir = ((root["output"] as? [String: Any])?["directory"] as? String) ?? ""
      if outDir.isEmpty { return [] }
      // Expand expected rack paths from manifest display names
      if rackNames.isEmpty {
        // fallback: directory marker if manifest not present
        return [ExpectedArtifactV1(kind: "rack", path: outDir + "/", minBytes: minBytes, warnBytes: warnBytes, job: job)]
      }
      return rackNames.map { dn in
        let fileName = sanitizeFileName(dn) + ".adg"
        return ExpectedArtifactV1(kind: "rack", path: outDir + "/" + fileName, minBytes: minBytes, warnBytes: warnBytes, job: job)
      }

    case "performance_set_export":
      let outPath = ((root["output"] as? [String: Any])?["path"] as? String) ?? ""
      if outPath.isEmpty { return [] }
      return [ExpectedArtifactV1(kind: "set_performance", path: outPath, minBytes: minBytes, warnBytes: warnBytes, job: job)]

    case "finishing_bays_export":
      var items: [ExpectedArtifactV1] = []
      let bays = root["bays"] as? [[String: Any]] ?? []
      for b in bays {
        if let p = b["output_path"] as? String, !p.isEmpty {
          items.append(ExpectedArtifactV1(kind: "set_finishing_bay", path: p, minBytes: minBytes, warnBytes: warnBytes, job: job))
        }
      }
      return items

    case "serum_base_export":
      let outPath = ((root["output"] as? [String: Any])?["path"] as? String) ?? ""
      if outPath.isEmpty { return [] }
      return [ExpectedArtifactV1(kind: "serum_patch", path: outPath, minBytes: minBytes, warnBytes: warnBytes, job: job)]

    case "extra_exports":
      var items: [ExpectedArtifactV1] = []
      let exports = root["exports"] as? [[String: Any]] ?? []
      for e in exports {
        if let p = e["output_path"] as? String, !p.isEmpty {
          items.append(ExpectedArtifactV1(kind: "rack", path: p, minBytes: minBytes, warnBytes: warnBytes, job: job))
        }
      }
      return items

    default:
      return []
    }
  }

  private static func sanitizeFileName(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    let cleaned = trimmed.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
    return cleaned.replacingOccurrences(of: "\\s+", with: "_", options: .regularExpression)
  }
}
