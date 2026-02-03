import Foundation

struct OperatorShellService {
  struct PathsResult {
    let lastReceiptPath: String?
    let lastRunDir: String?
    let latestReportPath: String?
    let lastFailuresDir: String?
  }

  static func collectPaths(runsDir: String) -> PathsResult {
    let lastRun = latestRunDirPath(runsDir: runsDir)
    return PathsResult(lastReceiptPath: lastRun.flatMap { findReceipt(in: $0) },
                       lastRunDir: lastRun,
                       latestReportPath: findReport(in: runsDir),
                       lastFailuresDir: findFailures(in: runsDir))
  }

  static func runShell(_ args: [String]) async throws -> Int32 {
    return try await withCheckedThrowingContinuation { cont in
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/bin/zsh")
      p.arguments = ["-lc", args.joined(separator: " ")]
      p.standardOutput = FileHandle.standardOutput
      p.standardError = FileHandle.standardError
      p.terminationHandler = { proc in cont.resume(returning: proc.terminationStatus) }
      do { try p.run() } catch { cont.resume(throwing: error) }
    }
  }

  static func runProcess(_ args: [String]) async throws -> Int32 {
    return try await withCheckedThrowingContinuation { cont in
      let p = Process()
      p.executableURL = URL(fileURLWithPath: args[0])
      p.arguments = Array(args.dropFirst())
      p.standardOutput = FileHandle.standardOutput
      p.standardError = FileHandle.standardError
      p.terminationHandler = { proc in cont.resume(returning: proc.terminationStatus) }
      do { try p.run() } catch { cont.resume(throwing: error) }
    }
  }

  static func openPath(_ path: String) async throws {
    _ = try await runShell(["open", shellEscape(path)])
  }

  static func latestRunDirPath(runsDir: String) -> String? {
    let runs = URL(fileURLWithPath: runsDir, isDirectory: true)
    guard FileManager.default.fileExists(atPath: runs.path) else { return nil }
    guard let items = try? FileManager.default.contentsOfDirectory(at: runs, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return nil }
    let dirs = items.filter { $0.hasDirectoryPath }
    let sorted = dirs.sorted { (a, b) -> Bool in
      let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
      let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
      return da > db
    }
    return sorted.first?.path
  }

  static func findReceipt(in runDir: String) -> String? {
    let fm = FileManager.default
    guard fm.fileExists(atPath: runDir) else { return nil }
    guard let files = try? fm.contentsOfDirectory(atPath: runDir) else { return nil }
    let receipts = files.filter { $0.hasSuffix("_receipt.v1.json") || $0 == "receipt.v1.json" }
    return receipts.sorted().last.map { "\(runDir)/\($0)" }
  }

  static func findReport(in runsDir: String) -> String? {
    let fm = FileManager.default
    guard fm.fileExists(atPath: runsDir) else { return nil }
    guard let dirs = try? fm.contentsOfDirectory(atPath: runsDir) else { return nil }
    for name in dirs.sorted().reversed() {
      let report = "\(runsDir)/\(name)/report.md"
      if fm.fileExists(atPath: report) { return report }
    }
    return nil
  }

  static func findFailures(in runsDir: String) -> String? {
    let fm = FileManager.default
    guard fm.fileExists(atPath: runsDir) else { return nil }
    guard let dirs = try? fm.contentsOfDirectory(atPath: runsDir) else { return nil }
    for name in dirs.sorted().reversed() {
      let failureDir = "\(runsDir)/\(name)/failures"
      var isDir: ObjCBool = false
      if fm.fileExists(atPath: failureDir, isDirectory: &isDir), isDir.boolValue { return failureDir }
    }
    return nil
  }

  private static func shellEscape(_ s: String) -> String {
    let escaped = s.replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(escaped)\""
  }
}
