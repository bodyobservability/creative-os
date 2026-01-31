import Foundation
import ArgumentParser
import Darwin

struct UI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ui",
    abstract: "Operator shell (TUI) for common workflows (v1.7.4)."
  )

  @Option(name: .long, help: "Anchors pack hint (stored in local config if provided).")
  var anchorsPack: String?

  @Flag(name: .long, help: "Do not execute commands; only print what would run.")
  var dryRun: Bool = false

  func run() async throws {
    let repoRoot = FileManager.default.currentDirectoryPath
    var cfg = try LocalConfig.loadOrCreate(atRepoRoot: repoRoot)

    if let ap = anchorsPack, !ap.isEmpty {
      cfg.anchorsPack = ap
      try cfg.save(atRepoRoot: repoRoot)
    }

    if cfg.anchorsPack == nil || cfg.anchorsPack == "" || (cfg.anchorsPack?.contains("<pack_id>") ?? false) {
      if let detected = LocalConfig.autoDetectAnchorsPack(repoRoot: repoRoot) {
        cfg.anchorsPack = detected
        try cfg.save(atRepoRoot: repoRoot)
      }
    }

    let ap = cfg.anchorsPack ?? "specs/automation/anchors/<pack_id>"
    let hv = resolveHVLIENBinary(repoRoot: repoRoot) ?? "hvlien"

    let items: [MenuItem] = [
      .init("Build CLI (release)", ["bash","-lc", "cd tools/automation/swift-cli && swift build -c release"], danger: false),
      .init("Doctor (modal guard sanity)", [hv, "doctor", "--modal-test", "detect", "--allow-ocr-fallback"], danger: false),
      .init("Calibrate regions", [hv, "calibrate-regions", "--regions-config", "tools/automation/swift-cli/config/regions.v1.json"], danger: true),
      .init("Validate anchors", [hv, "validate-anchors", "--regions-config", "tools/automation/swift-cli/config/regions.v1.json", "--pack", ap], danger: true),
      .init("MIDI list", [hv, "midi", "list"], danger: false),
      .init("VRL validate", [hv, "vrl", "validate", "--mapping", "specs/voice_runtime/v9_3_ableton_mapping.v1.yaml"], danger: false),

      .init("Assets: export ALL (repo completeness)", [hv, "assets", "export-all", "--anchors-pack", ap, "--overwrite"], danger: true),
      .init("Assets: export racks", [hv, "assets", "export-racks", "--anchors-pack", ap, "--overwrite", "ask"], danger: true),
      .init("Assets: export performance set", [hv, "assets", "export-performance-set", "--anchors-pack", ap, "--overwrite"], danger: true),
      .init("Assets: export finishing bays", [hv, "assets", "export-finishing-bays", "--anchors-pack", ap, "--overwrite"], danger: true),
      .init("Assets: export serum base", [hv, "assets", "export-serum-base", "--anchors-pack", ap, "--overwrite"], danger: true),
      .init("Assets: export extras", [hv, "assets", "export-extras", "--anchors-pack", ap, "--overwrite"], danger: true),

      .init("Index: build", [hv, "index", "build"], danger: false),
      .init("Index: status", [hv, "index", "status"], danger: false),
      .init("Drift: check", [hv, "drift", "check", "--anchors-pack-hint", ap], danger: false),
      .init("Drift: plan", [hv, "drift", "plan", "--anchors-pack-hint", ap], danger: false),
      .init("Drift: fix (guarded)", [hv, "drift", "fix", "--anchors-pack-hint", ap], danger: true),

      .init("Station: certify", [hv, "station", "certify"], danger: true),
      .init("Report: open last report", ["bash","-lc", "open " + (latestReportPath() ?? "runs")], danger: false),
      .init("Open last run folder", ["bash","-lc", "open " + (latestRunDir() ?? "runs")], danger: false),
    ]

    var selected = 0
    var lastCommandExit: Int32? = nil
    var lastReceiptPath: String? = nil
    var lastRunDir: String? = nil
    var lastFailuresDir: String? = nil

    let rec = recommendedNextAction(anchorsPack: cfg.anchorsPack)
    let stdinRaw = StdinRawMode()
    try stdinRaw.enable()
    defer { stdinRaw.disable() }

    while true {
      lastRunDir = latestRunDir()
      lastFailuresDir = latestFailuresDir(inRunDir: lastRunDir)

      printScreen(repoRoot: repoRoot,
                  hv: hv,
                  anchorsPack: ap,
                  lastRun: lastRunDir,
                  failuresDir: lastFailuresDir,
                  recommended: rec,
                  items: items,
                  selected: selected,
                  lastExit: lastCommandExit,
                  lastReceipt: lastReceiptPath)

      let key = readKey()
      switch key {
      case .quit:
        return
      case .up:
        selected = max(0, selected - 1)
      case .down:
        selected = min(items.count - 1, selected + 1)
      case .enter:
        let item = items[selected]
        if item.danger && !dryRun {
          stdinRaw.disable()
          print("\nThis action may click/type in Ableton or overwrite files.\nProceed? [y/N] ", terminator: "")
          let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
          try stdinRaw.enable()
          if ans != "y" && ans != "yes" { continue }
        }

        if dryRun {
          lastCommandExit = 0
          lastReceiptPath = nil
          continue
        }

        stdinRaw.disable()
        print("\n> Running: \(item.command.joined(separator: " "))\n")
        let code = try await runProcess(item.command)
        lastCommandExit = code
        lastRunDir = latestRunDir()
        lastReceiptPath = discoverLatestReceipt(inRunDir: lastRunDir)
        lastFailuresDir = latestFailuresDir(inRunDir: lastRunDir)
        print("\nExit: \(code)")
        if let rp = lastReceiptPath { print("Latest receipt: \(rp)") }
        if let fd = lastFailuresDir { print("Failures folder: \(fd)") }
        print("\nPress Enter to return to menu…", terminator: "")
        _ = readLine()
        try stdinRaw.enable()

      case .openReceipt:
        if let rp = lastReceiptPath {
          _ = try? await runProcess(["bash","-lc","open " + shellEscape(rp)])
        }
      case .openRun:
        if let rd = lastRunDir {
          _ = try? await runProcess(["bash","-lc","open " + shellEscape(rd)])
        }
      case .openReport:
        if let rp = latestReportPath() {
          _ = try? await runProcess(["bash","-lc","open " + shellEscape(rp)])
        }
      case .openFailures:
        if let fd = lastFailuresDir {
          _ = try? await runProcess(["bash","-lc","open " + shellEscape(fd)])
        }
      case .none:
        continue
      }
    }
  }

  func recommendedNextAction(anchorsPack: String?) -> String {
    if anchorsPack == nil || anchorsPack == "" || anchorsPack!.contains("<pack_id>") {
      return "No anchors pack configured/found → capture/validate anchors or pass --anchors-pack"
    }
    if !FileManager.default.fileExists(atPath: "checksums/index/artifact_index.v1.json") {
      return "Run: Index build (then Drift check)"
    }
    if let data = try? Data(contentsOf: URL(fileURLWithPath: "checksums/index/artifact_index.v1.json")),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let arts = obj["artifacts"] as? [[String: Any]] {
      var missing = 0, placeholder = 0
      for a in arts {
        if let st = a["status"] as? [String: Any], let state = st["state"] as? String {
          if state == "missing" { missing += 1 }
          if state == "placeholder" { placeholder += 1 }
        }
      }
      if missing + placeholder > 0 {
        return "Artifacts pending (missing/placeholder: \(missing + placeholder)) → run: Assets export ALL"
      }
    }
    return "Run: Drift check (then Station certify)"
  }

  struct MenuItem {
    let title: String
    let command: [String]
    let danger: Bool
    init(_ title: String, _ command: [String], danger: Bool) {
      self.title = title
      self.command = command
      self.danger = danger
    }
  }

  func printScreen(repoRoot: String,
                   hv: String,
                   anchorsPack: String,
                   lastRun: String?,
                   failuresDir: String?,
                   recommended: String,
                   items: [MenuItem],
                   selected: Int,
                   lastExit: Int32?,
                   lastReceipt: String?) {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    print("HVLIEN Operator Shell v1.7.5")
    print("repo: \(repoRoot)")
    print("hvlien: \(hv)")
    print("anchors-pack: \(anchorsPack)")
    print("last run: \(lastRun ?? "(none)")")
    if let fd = failuresDir { print("last failures: \(fd)") }
    print("recommended: \(recommended)")
    if let e = lastExit { print("last exit: \(e)") }
    if let r = lastReceipt { print("last receipt: \(r)") }
    print(String(repeating: "-", count: 72))
    print("↑/↓ j/k • Enter run • r receipt • o report • f run • x failures • q quit")
    print(String(repeating: "-", count: 72))

    for (i, it) in items.enumerated() {
      let flag = it.danger ? " *" : ""
      let cursor = (i == selected) ? "➜" : " "
      print("\(cursor) \(String(format: "%2d", i+1)) \(it.title)\(flag)")
    }
    print("\n(*) potentially destructive / clicky / overwriting")
  }

  func latestRunDir() -> String? {
    let runs = URL(fileURLWithPath: "runs", isDirectory: true)
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

  func latestFailuresDir(inRunDir runDir: String?) -> String? {
    guard let rd = runDir else { return nil }
    let p = URL(fileURLWithPath: rd).appendingPathComponent("failures", isDirectory: true).path
    guard FileManager.default.fileExists(atPath: p) else { return nil }
    // If failures contains subfolders, open the directory itself
    return p
  }

  func latestReportPath() -> String? {
    guard let rd = latestRunDir() else { return nil }
    let p = URL(fileURLWithPath: rd).appendingPathComponent("report.md").path
    return FileManager.default.fileExists(atPath: p) ? p : nil
  }

  func discoverLatestReceipt(inRunDir runDir: String?) -> String? {
    guard let rd = runDir else { return nil }
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: rd) else { return nil }
    let receiptFiles = files.filter { $0.contains("receipt") && $0.hasSuffix(".json") }
    guard !receiptFiles.isEmpty else { return nil }
    let chosen = receiptFiles.sorted().last!
    return URL(fileURLWithPath: rd).appendingPathComponent(chosen).path
  }

  func resolveHVLIENBinary(repoRoot: String) -> String? {
    let p1 = URL(fileURLWithPath: repoRoot).appendingPathComponent("tools/automation/swift-cli/.build/release/hvlien").path
    if FileManager.default.isExecutableFile(atPath: p1) { return p1 }
    return nil
  }

  func runProcess(_ args: [String]) async throws -> Int32 {
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

  enum Key { case up, down, enter, quit, openReceipt, openRun, openReport, openFailures, none }

  func readKey() -> Key {
    var buf: [UInt8] = [0,0,0]
    let n = read(STDIN_FILENO, &buf, 3)
    if n <= 0 { return .none }
    if buf[0] == 0x1B && buf[1] == 0x5B {
      if buf[2] == 0x41 { return .up }
      if buf[2] == 0x42 { return .down }
      return .none
    }
    let c = buf[0]
    if c == 0x0D || c == 0x0A { return .enter }
    if c == UInt8(ascii: "q") { return .quit }
    if c == UInt8(ascii: "r") { return .openReceipt }
    if c == UInt8(ascii: "f") { return .openRun }
    if c == UInt8(ascii: "o") { return .openReport }
    if c == UInt8(ascii: "x") { return .openFailures }
    if c == UInt8(ascii: "k") { return .up }
    if c == UInt8(ascii: "j") { return .down }
    return .none
  }

  func shellEscape(_ s: String) -> String {
    return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}

final class StdinRawMode {
  private var original = termios()
  private var hasOriginal = false

  func enable() throws {
    if !hasOriginal {
      tcgetattr(STDIN_FILENO, &original)
      hasOriginal = true
    }
    var raw = original
    raw.c_lflag &= ~UInt(ECHO | ICANON)
    raw.c_cc.16 = 1
    raw.c_cc.17 = 0
    tcsetattr(STDIN_FILENO, TCSANOW, &raw)
  }

  func disable() {
    if hasOriginal {
      var t = original
      tcsetattr(STDIN_FILENO, TCSANOW, &t)
    }
  }
}

extension UInt8 {
  init(ascii: Character) {
    self = Character(String(ascii)).asciiValue ?? 0
  }
}
