import Foundation
import Yams

enum SpecCompiler {
  static func compile(specPath: String, packSignaturesPath: String?, defaultFormats: [String]) throws -> CompiledSpec {
    let txt = try String(contentsOfFile: specPath, encoding: .utf8)
    let y = try Yams.load(yaml: txt)
    guard let root = y as? [String: Any] else { return CompiledSpec(deviceRequests: [], controllerRequests: [], packChecks: []) }

    let controllers = parseControllers(root["controllers"])
    let devices = parseTracks(root["tracks"], defaultFormats: defaultFormats)

    let tagSet = Set(devices.flatMap { $0.tags })
    let packChecks = try impliedPackChecks(tagSet: tagSet, packSignaturesPath: packSignaturesPath)

    return CompiledSpec(deviceRequests: devices, controllerRequests: controllers, packChecks: packChecks)
  }

  private static func parseControllers(_ node: Any?) -> [ControllerRequest] {
    guard let arr = node as? [Any] else { return [] }
    var out: [ControllerRequest] = []
    for any in arr {
      guard let m = any as? [String: Any] else { continue }
      out.append(ControllerRequest(
        id: m["id"] as? String ?? "ctrl:unknown",
        required: m["required"] as? Bool ?? false,
        expectedNameContains: (m["expected_name_contains"] as? [Any])?.compactMap { $0 as? String } ?? [],
        preferredManufacturer: m["preferred_manufacturer"] as? String,
        requireInputContains: (m["require_input_contains"] as? [Any])?.compactMap { $0 as? String },
        requireOutputContains: (m["require_output_contains"] as? [Any])?.compactMap { $0 as? String },
        expectedControlSurfaceName: m["ableton_control_surface"] as? String
      ))
    }
    return out
  }

  private static func parseTracks(_ node: Any?, defaultFormats: [String]) -> [DeviceRequest] {
    guard let tracks = node as? [Any] else { return [] }
    var out: [DeviceRequest] = []
    for t in tracks {
      guard let tm = t as? [String: Any] else { continue }
      let tname = tm["name"] as? String ?? "track"
      let ttype = tm["type"] as? String ?? "audio"
      guard let chain = tm["chain"] as? [Any] else { continue }
      for (i, devAny) in chain.enumerated() {
        guard let dev = devAny as? [String: Any] else { continue }
        let selector = dev["device"]
        var primary = ""
        var candidates: [String] = []
        var tags: [String] = []
        if let s = selector as? String {
          primary = s
        } else if let m = selector as? [String: Any] {
          primary = m["primary"] as? String ?? ""
          candidates = (m["candidates"] as? [Any])?.compactMap { $0 as? String } ?? []
          tags = (m["tags"] as? [Any])?.compactMap { $0 as? String } ?? []
        }
        if primary.isEmpty { continue }
        let mm = MatchMode(rawValue: (dev["match_mode"] as? String ?? "contains")) ?? .contains
        let required = dev["required"] as? Bool ?? true
        let id = "track:\(tname)/device:\(i):\(primary)"
        let plugin = dev["plugin"] as? [String: Any]
        let kindPref = (plugin != nil) ? ["plugin"] : ["ableton_audio_effect","ableton_midi_effect","ableton_instrument","ableton_max_for_live"]
        let fmtPref = (plugin?["format"] as? String).map { [$0] + defaultFormats.filter{$0 != $0} } ?? defaultFormats
        let vendorPref = (plugin?["vendor"] as? String).map { [$0] } ?? []
        out.append(DeviceRequest(
          id: id,
          primary: primary,
          candidates: candidates,
          matchMode: mm,
          required: required,
          tags: tags.map { StudioNormV1.normNameV1($0) }.filter { $0 != "__invalid__" },
          kindPreference: kindPref,
          formatPreference: fmtPref,
          vendorPreference: vendorPref,
          trackType: ttype
        ))
      }
    }
    return out
  }

  private static func impliedPackChecks(tagSet: Set<String>, packSignaturesPath: String?) throws -> [PackCheckRequest] {
    guard let p = packSignaturesPath, FileManager.default.fileExists(atPath: p) else { return [] }
    let doc = try JSONDecoder().decode(PackSignaturesDoc.self, from: Data(contentsOf: URL(fileURLWithPath: p)))
    var out: [PackCheckRequest] = []
    for pack in doc.packs {
      let any = Set((pack.impliedByTagsAny ?? []).map { StudioNormV1.normNameV1($0) }.filter { $0 != "__invalid__" })
      let all = Set((pack.impliedByTagsAll ?? []).map { StudioNormV1.normNameV1($0) }.filter { $0 != "__invalid__" })
      let anyHit = !any.isEmpty && !tagSet.intersection(any).isEmpty
      let allHit = !all.isEmpty && all.isSubset(of: tagSet)
      if anyHit || allHit {
        let because = Array(tagSet.intersection(any.union(all))).sorted()
        out.append(PackCheckRequest(id: "pack:\(pack.packId)", packId: pack.packId, required: true, becauseTags: because))
      }
    }
    return out
  }
}
