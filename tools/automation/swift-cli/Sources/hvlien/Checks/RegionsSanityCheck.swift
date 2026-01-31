import Foundation
struct RegionsSanityCheck: DoctorCheck {
  let id = "regions_sanity"
  func run(context: DoctorContext) async throws -> CheckResult {
    let art = DoctorArtifacts(baseDir: context.artifactsDir)
    let outDir = art.dir(for: id); try art.ensureDir(outDir)
    let regions = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: context.regionsPath))
    let required = ["browser.search","browser.results","tracks.list","device.chain"]
    let missing = required.filter { regions.cgRectTopLeft($0) == nil }
    var dump: [[String: Any]] = []
    for (k,r) in regions.regions { dump.append(["region_id":k,"x":r.x,"y":r.y,"w":r.w,"h":r.h]) }
    let data = try JSONSerialization.data(withJSONObject: dump, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: art.path(id,"regions_dump.json"))
    if !missing.isEmpty {
      return .fail(id, details: ["regions_path":context.regionsPath,"missing":missing.joined(separator: ",")], artifacts: [art.rel(id,"regions_dump.json")])
    }
    return .pass(id, details: ["regions_path":context.regionsPath], artifacts: [art.rel(id,"regions_dump.json")])
  }
}
