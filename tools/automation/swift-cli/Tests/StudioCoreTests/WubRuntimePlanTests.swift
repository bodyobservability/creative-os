import XCTest
@testable import StudioCore

final class WubRuntimePlanTests: XCTestCase {
  private func fixtureURL(name: String, ext: String, subdir: String) throws -> URL {
    let candidates: [String?] = [subdir, nil]
    for candidate in candidates {
      if let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: candidate) {
        return url
      }
    }
    XCTFail("Missing fixture: \(subdir)/\(name).\(ext)")
    throw NSError(domain: "fixtures", code: 1)
  }

  private func writeFixture(name: String, ext: String, subdir: String, to destination: URL) throws {
    let url = try fixtureURL(name: name, ext: ext, subdir: subdir)
    let data = try Data(contentsOf: url)
    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: destination, options: [.atomic])
  }

  func testWubPlanReportDeterministicOrdering() throws {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: tempDir) }

    try writeFixture(name: "hvlien.profile", ext: "yaml", subdir: "workspace/profiles",
                     to: tempDir.appendingPathComponent("profiles/hvlien.profile.yaml"))
    try writeFixture(name: "WUB_CONFIG", ext: "json", subdir: "workspace/notes",
                     to: tempDir.appendingPathComponent("notes/WUB_CONFIG.json"))

    let context = WubContext(runDir: nil,
                             runsDir: "runs",
                             sweeperConfig: SweeperConfig(anchorsPack: nil,
                                                          modalTest: "detect",
                                                          requiredControllers: [],
                                                          allowOcrFallback: false,
                                                          fix: false),
                             driftConfig: DriftConfig(anchorsPackHint: nil),
                             readyConfig: ReadyConfig(anchorsPackHint: "specs/automation/anchors/<pack_id>"),
                             stationConfig: nil,
                             assetsConfig: nil,
                             voiceRackSessionConfig: nil,
                             indexConfig: nil,
                             releaseConfig: nil,
                             reportConfig: nil,
                             repairConfig: nil,
                             storeRoot: tempDir)

    let report = try context.makePlanReport()
    let ordered = report.steps.sorted { ($0.agent, $0.id) < ($1.agent, $1.id) }
    XCTAssertEqual(report.steps.map { "\($0.agent)/\($0.id)" },
                   ordered.map { "\($0.agent)/\($0.id)" })
    XCTAssertFalse(report.steps.isEmpty)
  }
}
