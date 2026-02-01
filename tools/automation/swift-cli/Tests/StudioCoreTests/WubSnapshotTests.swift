import XCTest
@testable import StudioCore

final class WubSnapshotTests: XCTestCase {
  private func loadFixtureData(_ name: String) throws -> Data {
    let url = Bundle.module.url(forResource: name, withExtension: "json")
    XCTAssertNotNil(url, "Missing fixture: \(name).json")
    return try Data(contentsOf: url!)
  }

  private func normalizedJSON(_ data: Data) throws -> String {
    let obj = try JSONSerialization.jsonObject(with: data)
    let normalized = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys])
    return String(data: normalized, encoding: .utf8) ?? ""
  }

  private func makeTempWorkspace() throws -> URL {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    return tempDir
  }

  private func setupWorkspace(at dir: URL) throws -> String {
    let fm = FileManager.default
    try fm.createDirectory(at: dir.appendingPathComponent("profiles", isDirectory: true), withIntermediateDirectories: true)
    try fm.createDirectory(at: dir.appendingPathComponent("notes", isDirectory: true), withIntermediateDirectories: true)
    try fm.createDirectory(at: dir.appendingPathComponent("runs", isDirectory: true), withIntermediateDirectories: true)

    let profilePath = dir.appendingPathComponent("profiles/hvlien.profile.yaml")
    try "id: hvlien\nintents: []\npolicies: {}\nrequirements: {}\npacks:\n  - hvlien-defaults\n"
      .write(to: profilePath, atomically: true, encoding: .utf8)

    let runId = "2026-01-01_000000"
    let runDir = dir.appendingPathComponent("runs/\(runId)", isDirectory: true)
    try fm.createDirectory(at: runDir, withIntermediateDirectories: true)

    return runDir.path
  }

  func testWubSweepSnapshot() throws {
    let fm = FileManager.default
    let originalCwd = fm.currentDirectoryPath
    let tempDir = try makeTempWorkspace()
    defer {
      fm.changeCurrentDirectoryPath(originalCwd)
      try? fm.removeItem(at: tempDir)
    }

    XCTAssertTrue(fm.changeCurrentDirectoryPath(tempDir.path))
    let runDir = try setupWorkspace(at: tempDir)

    let context = WubContext(runDir: runDir, runsDir: "runs")
    let report = try context.makeSweepReport()

    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let actual = try normalizedJSON(enc.encode(report))
    let expected = try normalizedJSON(loadFixtureData("wub_sweep_snapshot"))

    XCTAssertEqual(actual, expected)
  }

  func testWubPlanSnapshot() throws {
    let fm = FileManager.default
    let originalCwd = fm.currentDirectoryPath
    let tempDir = try makeTempWorkspace()
    defer {
      fm.changeCurrentDirectoryPath(originalCwd)
      try? fm.removeItem(at: tempDir)
    }

    XCTAssertTrue(fm.changeCurrentDirectoryPath(tempDir.path))
    let runDir = try setupWorkspace(at: tempDir)

    let context = WubContext(runDir: runDir, runsDir: "runs")
    let report = try context.makePlanReport()

    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let actual = try normalizedJSON(enc.encode(report))
    let expected = try normalizedJSON(loadFixtureData("wub_plan_snapshot"))

    XCTAssertEqual(actual, expected)
  }

  func testWubPlanIncludesSweeperSteps() throws {
    let fm = FileManager.default
    let originalCwd = fm.currentDirectoryPath
    let tempDir = try makeTempWorkspace()
    defer {
      fm.changeCurrentDirectoryPath(originalCwd)
      try? fm.removeItem(at: tempDir)
    }

    XCTAssertTrue(fm.changeCurrentDirectoryPath(tempDir.path))
    let runDir = try setupWorkspace(at: tempDir)

    let sweeperReport = DubSweeperReportV1(schemaVersion: 1,
                                           runId: "2026-01-01_000000",
                                           timestamp: "2026-01-01T00:00:00Z",
                                           status: .fail,
                                           checks: [],
                                           safeSteps: [DubSweeperStep(id: "safe_1", description: "Run safe sweep")],
                                           manualSteps: [DubSweeperStep(id: "manual_1", description: "Confirm manual step")],
                                           artifactsDir: "runs/2026-01-01_000000/sweeper")
    try JSONIO.save(sweeperReport, to: URL(fileURLWithPath: runDir).appendingPathComponent("sweeper_report.v1.json"))

    let context = WubContext(runDir: runDir, runsDir: "runs")
    let report = try context.makePlanReport()

    let ids = report.steps.map { $0.id }
    XCTAssertTrue(ids.contains("safe_1"))
    XCTAssertTrue(ids.contains("manual_1"))
    let reasons = report.steps.reduce(into: [String: String]()) { acc, step in acc[step.id] = step.manualReason }
    XCTAssertEqual(reasons["safe_1"], "sweep_safe")
    XCTAssertEqual(reasons["manual_1"], "sweep_manual")
  }
}
