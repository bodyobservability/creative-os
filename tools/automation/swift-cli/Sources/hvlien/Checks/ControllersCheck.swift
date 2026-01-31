import Foundation
struct ControllersCheck: DoctorCheck {
  let id = "controllers"
  func run(context: DoctorContext) async throws -> CheckResult {
    let art = DoctorArtifacts(baseDir: context.artifactsDir)
    let outDir = art.dir(for: id); try art.ensureDir(outDir)
    let inv = buildControllersInventoryDoc(ableton: "12.3")
    try JSONIO.save(inv, to: art.path(id,"controllers_inventory.v1.json"))
    if context.requiredControllers.isEmpty {
      return .pass(id, details:["required":"none","found_count":"\(inv.devices.count)"], artifacts:[art.rel(id,"controllers_inventory.v1.json")])
    }
    let found = inv.devices.map { HVLIENNormV1.normNameV1($0.displayName) }
    var missing: [String] = []
    for rc in context.requiredControllers {
      let n = HVLIENNormV1.normNameV1(rc)
      if !found.contains(where: { $0.contains(n) }) { missing.append(rc) }
    }
    if !missing.isEmpty {
      return .fail(id, details:["missing_required": missing.joined(separator:",")], artifacts:[art.rel(id,"controllers_inventory.v1.json")])
    }
    return .pass(id, details:["missing_required":""], artifacts:[art.rel(id,"controllers_inventory.v1.json")])
  }
}
