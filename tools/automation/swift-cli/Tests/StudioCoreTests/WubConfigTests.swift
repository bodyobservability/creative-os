import XCTest
@testable import StudioCore

final class WubConfigTests: XCTestCase {

  private func wubExecutableURL() -> URL {
    let testFile = URL(fileURLWithPath: #filePath)
    let packageRoot = testFile
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    return packageRoot.appendingPathComponent(".build/debug/wub")
  }

  private func runWub(_ arguments: [String]) throws -> (status: Int32, output: String) {
    let wubURL = wubExecutableURL()
    guard FileManager.default.fileExists(atPath: wubURL.path) else {
      XCTFail("Missing wub executable at \(wubURL.path)")
      return (status: -1, output: "")
    }

    let process = Process()
    process.executableURL = wubURL
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    return (process.terminationStatus, output)
  }

  func testConfigCreatedFromFirstProfile() throws {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let originalCwd = fm.currentDirectoryPath
    defer {
      fm.changeCurrentDirectoryPath(originalCwd)
      try? fm.removeItem(at: tempDir)
    }

    XCTAssertTrue(fm.changeCurrentDirectoryPath(tempDir.path))

    try fm.createDirectory(at: tempDir.appendingPathComponent("profiles", isDirectory: true), withIntermediateDirectories: true)
    try fm.createDirectory(at: tempDir.appendingPathComponent("notes", isDirectory: true), withIntermediateDirectories: true)

    let profilePath = tempDir.appendingPathComponent("profiles/test.profile.yaml")
    try "id: test\nintents: []\npolicies: {}\nrequirements: {}\npacks: []\n"
      .write(to: profilePath, atomically: true, encoding: .utf8)

    let store = WubStore()
    let profiles = try store.loadProfiles()
    XCTAssertEqual(profiles.map { $0.id }, ["test"])

    let config = try store.loadOrCreateConfig(defaultProfileId: profiles.first?.id)
    XCTAssertEqual(config.activeProfileId, "test")

    let configUrl = tempDir.appendingPathComponent(store.configPath)
    XCTAssertTrue(fm.fileExists(atPath: configUrl.path))

    let diskConfig = try JSONIO.load(WubConfig.self, from: configUrl)
    XCTAssertEqual(diskConfig.activeProfileId, "test")
  }

  func testWubProfileUsePersistsSelection() async throws {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let originalCwd = fm.currentDirectoryPath
    defer {
      fm.changeCurrentDirectoryPath(originalCwd)
      try? fm.removeItem(at: tempDir)
    }

    XCTAssertTrue(fm.changeCurrentDirectoryPath(tempDir.path))

    try fm.createDirectory(at: tempDir.appendingPathComponent("profiles", isDirectory: true), withIntermediateDirectories: true)
    try fm.createDirectory(at: tempDir.appendingPathComponent("notes", isDirectory: true), withIntermediateDirectories: true)

    let profilePath = tempDir.appendingPathComponent("profiles/hvlien.profile.yaml")
    try "id: hvlien\nintents: []\npolicies: {}\nrequirements: {}\npacks: []\n"
      .write(to: profilePath, atomically: true, encoding: .utf8)

    var command = WubProfileUse()
    command.profileId = "hvlien"
    try await command.run()

    let store = WubStore()
    let configUrl = tempDir.appendingPathComponent(store.configPath)
    let diskConfig = try JSONIO.load(WubConfig.self, from: configUrl)
    XCTAssertEqual(diskConfig.activeProfileId, "hvlien")
  }

  func testActivePackSelectionIncludedInDesiredState() throws {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let originalCwd = fm.currentDirectoryPath
    defer {
      fm.changeCurrentDirectoryPath(originalCwd)
      try? fm.removeItem(at: tempDir)
    }

    XCTAssertTrue(fm.changeCurrentDirectoryPath(tempDir.path))

    try fm.createDirectory(at: tempDir.appendingPathComponent("profiles", isDirectory: true), withIntermediateDirectories: true)
    try fm.createDirectory(at: tempDir.appendingPathComponent("packs/hvlien-defaults", isDirectory: true), withIntermediateDirectories: true)
    try fm.createDirectory(at: tempDir.appendingPathComponent("notes", isDirectory: true), withIntermediateDirectories: true)

    let profilePath = tempDir.appendingPathComponent("profiles/hvlien.profile.yaml")
    try "id: hvlien\nintents: []\npolicies: {}\nrequirements: {}\npacks: []\n"
      .write(to: profilePath, atomically: true, encoding: .utf8)

    let packPath = tempDir.appendingPathComponent("packs/hvlien-defaults/pack.yaml")
    try "id: hvlien-defaults\napplies_to:\n  - hvlien\ncontents: {}\nrequires_explicit_apply: false\n"
      .write(to: packPath, atomically: true, encoding: .utf8)

    let store = WubStore()
    let config = WubConfig(activeProfileId: "hvlien",
                           activePackIds: ["hvlien-defaults"],
                           lastUpdated: "2026-01-01T00:00:00Z")
    try JSONIO.save(config, to: tempDir.appendingPathComponent(store.configPath))

    let context = WubContext(runDir: nil, runsDir: "runs")
    let desired = try context.makeSweepReport().desired
    XCTAssertTrue(desired.slices.contains { $0.agentId == "pack:hvlien-defaults" })
  }


  func testWubProfileUseCliEndToEnd() throws {
    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)

    let originalCwd = fm.currentDirectoryPath
    defer {
      fm.changeCurrentDirectoryPath(originalCwd)
      try? fm.removeItem(at: tempDir)
    }

    XCTAssertTrue(fm.changeCurrentDirectoryPath(tempDir.path))

    try fm.createDirectory(at: tempDir.appendingPathComponent("profiles", isDirectory: true), withIntermediateDirectories: true)
    try fm.createDirectory(at: tempDir.appendingPathComponent("notes", isDirectory: true), withIntermediateDirectories: true)

    let profilePath = tempDir.appendingPathComponent("profiles/hvlien.profile.yaml")
    try "id: hvlien\nintents: []\npolicies: {}\nrequirements: {}\npacks: []\n"
      .write(to: profilePath, atomically: true, encoding: .utf8)

    let result = try runWub(["profile", "use", "hvlien"])
    XCTAssertEqual(result.status, 0, "wub output: \(result.output)")

    let store = WubStore()
    let configUrl = tempDir.appendingPathComponent(store.configPath)
    let diskConfig = try JSONIO.load(WubConfig.self, from: configUrl)
    XCTAssertEqual(diskConfig.activeProfileId, "hvlien")
  }
}
