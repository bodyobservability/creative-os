import Foundation

struct RunLocator {
  let runsDir: String

  func latestRunDir() -> String? {
    OperatorShellService.latestRunDirPath(runsDir: runsDir)
  }

  func latestFailuresDir(inRunDir runDir: String?) -> String? {
    if let rd = runDir {
      let p = URL(fileURLWithPath: rd).appendingPathComponent("failures", isDirectory: true).path
      if FileManager.default.fileExists(atPath: p) { return p }
    }
    return OperatorShellService.findFailures(in: runsDir)
  }

  func latestReportPath() -> String? {
    OperatorShellService.findReport(in: runsDir)
  }

  func latestReceipt(inRunDir runDir: String?) -> String? {
    guard let rd = runDir else { return nil }
    return OperatorShellService.findReceipt(in: rd)
  }

  func latestReadyReportPath(inRunDir runDir: String?) -> String? {
    guard let rd = runDir else { return nil }
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: rd) else { return nil }
    let candidates = files.filter { $0.hasPrefix("ready_report") && $0.hasSuffix(".json") }.sorted()
    guard let chosen = candidates.last else { return nil }
    return URL(fileURLWithPath: rd).appendingPathComponent(chosen).path
  }
}
