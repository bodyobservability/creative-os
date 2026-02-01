import Foundation
import AppKit
import ArgumentParser
import Darwin

struct UI: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "ui",
    abstract: "Operator shell (TUI) for common workflows (v1.7.15)."
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

    // First-run wizard (runs once; stored in notes/LOCAL_CONFIG.json)
    if (cfg.firstRunCompleted ?? false) == false {
      try await runFirstRunWizard(repoRoot: repoRoot,
                                  hv: hv,
                                  anchorsPack: cfg.anchorsPack ?? "specs/automation/anchors/<pack_id>",
                                  cfg: &cfg)
    }


    let allItems: [MenuItem] = buildMenu(hv: hv, anchorsPack: ap)

    // UI modes
    var voiceMode = false           // minimizes letters/keys, emphasizes numbers
    var studioMode = true           // hide risky commands by default
    var showAll = false             // TOP/ALL view (when studioMode is off, this is the normal toggle)
    var selected = 0

    // transient state
    var lastCommandExit: Int32? = nil
    var lastReceiptPath: String? = nil
    var lastRunDir: String? = nil
    var lastFailuresDir: String? = nil

    let stdinRaw = StdinRawMode()
    try stdinRaw.enable()
    defer { stdinRaw.disable() }

    while true {
      // dynamic filtered view
      let items = visibleItems(all: allItems, studioMode: studioMode, showAll: showAll)
      selected = min(selected, max(0, items.count - 1))

      lastRunDir = latestRunDir()
      lastFailuresDir = latestFailuresDir(inRunDir: lastRunDir)

      let state = DashboardState.load(lastRunDir: lastRunDir)
      let readyReport = latestReadyReport(inRunDir: lastRunDir)
      let rec = recommendedNextAction(cfgAnchorsPack: cfg.anchorsPack,
                                      state: state,
                                      ready: readyReport,
                                      hv: hv,
                                      anchorsPack: ap)
      let displayCheck = displayTargetCheck(anchorsPack: ap)

      printScreen(repoRoot: repoRoot,
                  hv: hv,
                  anchorsPack: ap,
                  displayInfo: displayCheck.info,
                  displayWarning: displayCheck.warning,
                  voiceMode: voiceMode,
                  studioMode: studioMode,
                  showAll: showAll,
                  lastRun: lastRunDir,
                  failuresDir: lastFailuresDir,
                  state: state,
                  recommended: rec.summary,
                  items: items,
                  selected: selected,
                  lastExit: lastCommandExit,
                  lastReceipt: lastReceiptPath,
                  readyStatus: readyReport?.status)

      let key = readKey()
      switch key {
      case .quit:
        return

      case .toggleVoiceMode:
        voiceMode.toggle()
        continue

      case .toggleStudioMode:
        studioMode.toggle()
        selected = 0
        continue

      case .toggleAll:
        showAll.toggle()
        selected = 0
        continue

      case .refresh:
        continue

      case .up:
        selected = max(0, selected - 1)

      case .down:
        selected = min(items.count - 1, selected + 1)

      case .previewDriftPlan:
        stdinRaw.disable()
        print("\n# Drift remediation plan (preview)\n")
        if dryRun {
          print("(dry-run) would run: \(hv) drift plan --anchors-pack-hint \(ap)\n")
        } else {
          let output = try await captureProcessOutput([hv, "drift", "plan", "--anchors-pack-hint", ap])
          print(output.isEmpty ? "(no output)" : output)
        }
        print("\nPress Enter to return…", terminator: "")
        _ = readLine()
        try stdinRaw.enable()

      case .readyVerify:
        stdinRaw.disable()
        print("\n# READY verifier\n")
        if dryRun {
          print("(dry-run) would run: \(hv) ready --anchors-pack-hint \(ap)\n")
        } else {
          let output = try await captureProcessOutput([hv, "ready", "--anchors-pack-hint", ap])
          print(output.isEmpty ? "(no output)" : output)
        }
        print("\nPress Enter to return…", terminator: "")
        _ = readLine()
        try stdinRaw.enable()

      case .runRecommended:
        if let action = rec.action {
          try await runAction(action, stdinRaw: stdinRaw, dryRun: dryRun,
                              lastExit: &lastCommandExit, lastReceipt: &lastReceiptPath,
                              lastRunDir: &lastRunDir, lastFailuresDir: &lastFailuresDir)
        }
        continue

      case .enter:
        let item = items[selected]
        try await runAction(.init(command: item.command, danger: item.danger, label: item.title),
                            stdinRaw: stdinRaw, dryRun: dryRun,
                            lastExit: &lastCommandExit, lastReceipt: &lastReceiptPath,
                            lastRunDir: &lastRunDir, lastFailuresDir: &lastFailuresDir)

      case .openReceipt:
        if let rp = lastReceiptPath { _ = try? await runProcess(["bash","-lc","open " + shellEscape(rp)]) }
      case .openRun:
        if let rd = lastRunDir { _ = try? await runProcess(["bash","-lc","open " + shellEscape(rd)]) }
      case .openReport:
        if let rp = latestReportPath() { _ = try? await runProcess(["bash","-lc","open " + shellEscape(rp)]) }
      case .openFailures:
        if let fd = lastFailuresDir { _ = try? await runProcess(["bash","-lc","open " + shellEscape(fd)]) }

      case .selectNumber(let n):
        // Voice Mode: allow direct numeric selection ("press 3")
        if n >= 1 && n <= items.count {
          selected = n - 1
          let item = items[selected]
          try await runAction(.init(command: item.command, danger: item.danger, label: item.title),
                              stdinRaw: stdinRaw, dryRun: dryRun,
                              lastExit: &lastCommandExit, lastReceipt: &lastReceiptPath,
                              lastRunDir: &lastRunDir, lastFailuresDir: &lastFailuresDir)
        }
      case .none:
        continue
      }
    }
  }

  // MARK: Menu & modes

  struct MenuItem {
    let title: String
    let command: [String]
    let danger: Bool
    let category: String
  }

  func buildMenu(hv: String, anchorsPack: String) -> [MenuItem] {
    [
      .init(title: "Doctor (modal guard sanity)", command: [hv, "doctor", "--modal-test", "detect", "--allow-ocr-fallback"], danger: false, category: "Safety"),
      .init(title: "MIDI list", command: [hv, "midi", "list"], danger: false, category: "Runtime"),
      .init(title: "VRL validate", command: [hv, "vrl", "validate", "--mapping", "specs/voice_runtime/v9_3_ableton_mapping.v1.yaml"], danger: false, category: "Runtime"),

      .init(title: "Assets: export ALL (repo completeness)", command: [hv, "assets", "export-all", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports"),
      .init(title: "Assets: export racks", command: [hv, "assets", "export-racks", "--anchors-pack", anchorsPack, "--overwrite", "ask"], danger: true, category: "Exports"),
      .init(title: "Assets: export performance set", command: [hv, "assets", "export-performance-set", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports"),
      .init(title: "Assets: export finishing bays", command: [hv, "assets", "export-finishing-bays", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports"),
      .init(title: "Assets: export serum base", command: [hv, "assets", "export-serum-base", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports"),
      .init(title: "Assets: export extras", command: [hv, "assets", "export-extras", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports"),

      .init(title: "Index: build", command: [hv, "index", "build"], danger: false, category: "Index"),
      .init(title: "Index: status", command: [hv, "index", "status"], danger: false, category: "Index"),
      .init(title: "Drift: check", command: [hv, "drift", "check", "--anchors-pack-hint", anchorsPack], danger: false, category: "Drift"),
      .init(title: "Drift: plan", command: [hv, "drift", "plan", "--anchors-pack-hint", anchorsPack], danger: false, category: "Drift"),
      .init(title: "Drift: fix (guarded)", command: [hv, "drift", "fix", "--anchors-pack-hint", anchorsPack], danger: true, category: "Drift"),

      .init(title: "Ready: verify", command: [hv, "ready", "--anchors-pack-hint", anchorsPack], danger: false, category: "Governance"),
      .init(title: "Station: certify", command: [hv, "station", "certify"], danger: true, category: "Governance"),
      .init(title: "Open last report", command: ["bash","-lc", "open " + (latestReportPath() ?? "runs")], danger: false, category: "Open"),
      .init(title: "Open last run folder", command: ["bash","-lc", "open " + (latestRunDir() ?? "runs")], danger: false, category: "Open"),
    ]
  }

  func visibleItems(all: [MenuItem], studioMode: Bool, showAll: Bool) -> [MenuItem] {
    if studioMode {
      // Hide risky by default: safe-only view.
      // Allow a few "safe but important" actions.
      let safe = all.filter { !$0.danger }
      // Keep top essentials even if dangerous? no: studio mode is strict.
      return safe
    } else {
      // Non-studio mode: TOP vs ALL
      if showAll { return all }
      let topTitles: Set<String> = [
        "Doctor (modal guard sanity)",
        "Assets: export ALL (repo completeness)",
        "Index: build",
        "Drift: check",
        "Drift: plan",
        "Drift: fix (guarded)",
        "VRL validate",
        "Ready: verify",
        "Station: certify",
        "Open last report",
        "Open last run folder"
      ]
      return all.filter { topTitles.contains($0.title) }
    }
  }

  // MARK: recommended next action

  struct RecommendedAction {
    let summary: String
    let action: Action?
    struct Action { let command: [String]; let danger: Bool; let label: String }
  }

  func recommendedNextAction(cfgAnchorsPack: String?,
                             state: DashboardState,
                             ready: ReadyReportV1?,
                             hv: String,
                             anchorsPack: String) -> RecommendedAction {
    if cfgAnchorsPack == nil || cfgAnchorsPack == "" || (cfgAnchorsPack?.contains("<pack_id>") ?? false) {
      return .init(summary: "No anchors pack configured/found → set anchors-pack", action: nil)
    }
    if let r = ready {
      if let cmd = r.recommendedCommands.first, let action = recommendedActionFromCommand(cmd, hv: hv) {
        return .init(summary: "Ready: \(r.status) → \(cmd)", action: action)
      }
      if r.status == "not_ready" {
        return .init(summary: "Ready: NOT_READY → run Ready verify", action: .init(command: [hv,"ready","--anchors-pack-hint", anchorsPack], danger: false, label: "Ready: verify"))
      }
    }
    if !state.indexExists {
      return .init(summary: "Run Index build", action: .init(command: [hv,"index","build"], danger: false, label: "Index: build"))
    }
    if state.driftStatus == "fail" {
      return .init(summary: "Drift FAIL → run Drift fix (guarded)", action: .init(command: [hv,"drift","fix","--anchors-pack-hint", anchorsPack], danger: true, label: "Drift: fix (guarded)"))
    }
    if state.pendingArtifacts > 0 {
      return .init(summary: "Artifacts pending (\(state.pendingArtifacts)) → run Export ALL", action: .init(command: [hv,"assets","export-all","--anchors-pack", anchorsPack, "--overwrite"], danger: true, label: "Assets: export ALL (repo completeness)"))
    }
    return .init(summary: "Healthy → Drift check, then Station certify", action: .init(command: [hv,"drift","check","--anchors-pack-hint", anchorsPack], danger: false, label: "Drift: check"))
  }

  // MARK: Dashboard state

  struct DashboardState {
    let indexExists: Bool
    let pendingArtifacts: Int
    let driftStatus: String?
    let lastExportAllStatus: String?

    static func load(lastRunDir: String?) -> DashboardState {
      let idxPath = "checksums/index/artifact_index.v1.json"
      let indexExists = FileManager.default.fileExists(atPath: idxPath)
      var pending = 0
      if indexExists,
         let data = try? Data(contentsOf: URL(fileURLWithPath: idxPath)),
         let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let arts = obj["artifacts"] as? [[String: Any]] {
        for a in arts {
          if let st = a["status"] as? [String: Any], let state = st["state"] as? String {
            if state == "missing" || state == "placeholder" { pending += 1 }
          }
        }
      }
      let driftStatus = lastRunDir.flatMap { readStatusInDir(dir: $0, prefix: "drift_report") }
      let exportAllStatus = lastRunDir.flatMap { readStatusContains(dir: $0, contains: "assets_export_all_receipt") }
      return .init(indexExists: indexExists, pendingArtifacts: pending, driftStatus: driftStatus, lastExportAllStatus: exportAllStatus)
    }

    private static func readStatusInDir(dir: String, prefix: String) -> String? {
      let fm = FileManager.default
      guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
      let candidates = files.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }.sorted()
      guard let chosen = candidates.last else { return nil }
      return readStatus(fromJSON: URL(fileURLWithPath: dir).appendingPathComponent(chosen).path)
    }

    private static func readStatusContains(dir: String, contains: String) -> String? {
      let fm = FileManager.default
      guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
      let candidates = files.filter { $0.contains(contains) && $0.hasSuffix(".json") }.sorted()
      guard let chosen = candidates.last else { return nil }
      return readStatus(fromJSON: URL(fileURLWithPath: dir).appendingPathComponent(chosen).path)
    }

    private static func readStatus(fromJSON path: String) -> String? {
      guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
      return obj["status"] as? String
    }
  }

  // MARK: run action helper

  func runAction(_ action: RecommendedAction.Action,
                 stdinRaw: StdinRawMode,
                 dryRun: Bool,
                 lastExit: inout Int32?,
                 lastReceipt: inout String?,
                 lastRunDir: inout String?,
                 lastFailuresDir: inout String?) async throws {
    if action.danger && !dryRun {
      stdinRaw.disable()
      print("\nThis action may click/type or overwrite files.\nProceed? [y/N] ", terminator: "")
      let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
      try stdinRaw.enable()
      if ans != "y" && ans != "yes" { return }
    }
    if dryRun { lastExit = 0; return }
    stdinRaw.disable()
    print("\n> Running: \(action.command.joined(separator: " "))\n")
    let code = try await runProcess(action.command)
    lastExit = code
    lastRunDir = latestRunDir()
    lastReceipt = discoverLatestReceipt(inRunDir: lastRunDir)
    lastFailuresDir = latestFailuresDir(inRunDir: lastRunDir)
    print("\nExit: \(code)")
    if let rp = lastReceipt { print("Latest receipt: \(rp)") }
    if let fd = lastFailuresDir { print("Failures folder: \(fd)") }
    print("\nPress Enter to return…", terminator: "")
    _ = readLine()
    try stdinRaw.enable()
  }

  // MARK: render

  func printScreen(repoRoot: String,
                   hv: String,
                   anchorsPack: String,
                   displayInfo: String?,
                   displayWarning: String?,
                   voiceMode: Bool,
                   studioMode: Bool,
                   showAll: Bool,
                   lastRun: String?,
                   failuresDir: String?,
                   state: DashboardState,
                   recommended: String,
                   items: [MenuItem],
                   selected: Int,
                   lastExit: Int32?,
                   lastReceipt: String?,
                   readyStatus: String?) {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    print("HVLIEN Operator Shell v1.7.15")
    print("anchors-pack: \(anchorsPack)")
    if let info = displayInfo {
      print("display: \(info)")
    }
    if let warn = displayWarning {
      print("display warning: \(warn)")
    }
    print("last run: \(lastRun ?? "(none)")")
    if let fd = failuresDir { print("last failures: \(fd)") }
    print("recommended: \(recommended)")
    let readyBadge = readyStatus?.uppercased() ?? "-"
    print("badges: ready=\(readyBadge) index=\(state.indexExists ? "✅" : "❌") pending=\(state.pendingArtifacts) drift=\(state.driftStatus ?? "-") exportAll=\(state.lastExportAllStatus ?? "-")")
    if let e = lastExit { print("last exit: \(e)") }
    if let r = lastReceipt { print("last receipt: \(r)") }

    print(String(repeating: "-", count: 88))
    print("modes: voice=\(voiceMode ? "ON" : "OFF") (v)  studio=\(studioMode ? "ON" : "OFF") (s)  all=\(showAll ? "ON" : "OFF") (a)")
    print("keys: ↑/↓ j/k • Enter run • Space recommended • p plan • c ready • R refresh • r/o/f/x • q quit")
    if voiceMode { print("voice hint: Say \"press 3\" (then Enter) or use number keys 1-9.") }
    print(String(repeating: "-", count: 88))

    // In voice mode, show explicit numeric guidance
    for (i, it) in items.enumerated() {
      let num = i + 1
      let flag = it.danger ? " *" : ""
      let cursor = (i == selected) ? "➜" : " "
      if voiceMode {
        print("\(cursor) [\(num)] \(it.title)\(flag)   (Say: \"press \(num)\")")
      } else {
        print("\(cursor) \(String(format: "%2d", num)) \(it.title)\(flag)")
      }
    }
    print("\n(*) risky (hidden in Studio Mode)")
  }

  // MARK: FS helpers

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
    return FileManager.default.fileExists(atPath: p) ? p : nil
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

  func latestReadyReport(inRunDir runDir: String?) -> ReadyReportV1? {
    guard let rd = runDir else { return nil }
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: rd) else { return nil }
    let candidates = files.filter { $0.hasPrefix("ready_report") && $0.hasSuffix(".json") }.sorted()
    guard let chosen = candidates.last else { return nil }
    let path = URL(fileURLWithPath: rd).appendingPathComponent(chosen)
    return try? JSONIO.load(ReadyReportV1.self, from: path)
  }

  func recommendedActionFromCommand(_ cmd: String, hv: String) -> RecommendedAction.Action? {
    let parts = cmd.split(separator: " ").map(String.init)
    guard !parts.isEmpty else { return nil }
    var args = parts
    if args.first == "hvlien" { args[0] = hv }
    let danger = cmd.contains("export-all") || cmd.contains("drift fix") || cmd.contains("assets export")
    return .init(command: args, danger: danger, label: cmd)
  }

  func resolveHVLIENBinary(repoRoot: String) -> String? {
    let p1 = URL(fileURLWithPath: repoRoot).appendingPathComponent("tools/automation/swift-cli/.build/release/hvlien").path
    return FileManager.default.isExecutableFile(atPath: p1) ? p1 : nil
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

  func captureProcessOutput(_ args: [String]) async throws -> String {
    return try await withCheckedThrowingContinuation { cont in
      let p = Process()
      p.executableURL = URL(fileURLWithPath: args[0])
      p.arguments = Array(args.dropFirst())
      let out = Pipe()
      let err = Pipe()
      p.standardOutput = out
      p.standardError = err
      p.terminationHandler = { _ in
        let od = out.fileHandleForReading.readDataToEndOfFile()
        let ed = err.fileHandleForReading.readDataToEndOfFile()
        let s = (String(data: od, encoding: .utf8) ?? "") + (String(data: ed, encoding: .utf8) ?? "")
        cont.resume(returning: s.trimmingCharacters(in: .whitespacesAndNewlines))
      }
      do { try p.run() } catch { cont.resume(throwing: error) }
    }
  }

  // MARK: input

  enum Key {
    case up, down, enter, quit
    case openReceipt, openRun, openReport, openFailures
    case toggleAll, refresh, runRecommended, previewDriftPlan, readyVerify
    case toggleVoiceMode, toggleStudioMode
    case selectNumber(Int)
    case none
  }

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

    // number keys 1-9 -> select
    if c >= asciiByte("1") && c <= asciiByte("9") {
      return .selectNumber(Int(c - asciiByte("0")))
    }

    if c == 0x20 { return .runRecommended }
    if c == asciiByte("p") { return .previewDriftPlan }
    if c == asciiByte("c") { return .readyVerify }
    if c == asciiByte("v") { return .toggleVoiceMode }
    if c == asciiByte("s") { return .toggleStudioMode }
    if c == 0x0D || c == 0x0A { return .enter }
    if c == asciiByte("q") { return .quit }
    if c == asciiByte("r") { return .openReceipt }
    if c == asciiByte("f") { return .openRun }
    if c == asciiByte("o") { return .openReport }
    if c == asciiByte("x") { return .openFailures }
    if c == asciiByte("a") { return .toggleAll }
    if c == asciiByte("R") { return .refresh }
    if c == asciiByte("k") { return .up }
    if c == asciiByte("j") { return .down }
    return .none
  }

  private func asciiByte(_ s: String) -> UInt8 {
    return s.utf8.first ?? 0
  }

  func shellEscape(_ s: String) -> String {
    return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }

  // MARK: First-run wizard
  private func runFirstRunWizard(repoRoot: String,
                                 hv: String,
                                 anchorsPack: String,
                                 cfg: inout LocalConfig) async throws {
    // Wizard runs in cooked mode (outside raw-key loop).
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    print("HVLIEN First-Run Wizard (v1.7.15)")
    print(String(repeating: "=", count: 72))
    print("Goal: establish a safe baseline with minimal friction.\n")
    print("Anchors pack: \(anchorsPack)")

    let wizardRunId = RunContext.makeRunId()
    var wizardSteps: [WizardStep] = []
    let wizardNotes: [String] = []
    var wizardStatus: String = "pass"
    var sawSkip = false

    print("\nRecommended steps:")
    print("  1) Build CLI")
    print("  2) Doctor (permissions + modal safety)")
    print("  3) Index build (v1.8)")
    print("\nYou can skip any step. Nothing runs without confirmation.\n")

    _ = await wizardRunStep(id: "build",
                            command: ["bash","-lc","cd tools/automation/swift-cli && swift build -c release"],
                            prompt: "Run build now? (swift build -c release)",
                            steps: &wizardSteps,
                            status: &wizardStatus)
    _ = await wizardRunStep(id: "doctor",
                            command: [hv,"doctor","--modal-test","detect","--allow-ocr-fallback"],
                            prompt: "Run doctor now?",
                            steps: &wizardSteps,
                            status: &wizardStatus)
    _ = await wizardRunStep(id: "index_build",
                            command: [hv,"index","build"],
                            prompt: "Run index build now?",
                            steps: &wizardSteps,
                            status: &wizardStatus)

    // Step 4) Export preflight + 5) Asset exports (recommended)
    if detectPendingArtifacts() {
      print("\nStep 4) Export preflight (recommended)")
      print("This checks regions, OCR visibility, and anchors before running exports.\n")

      _ = await wizardRunStep(
        id: "export_preflight",
        command: [hv,"assets","preflight","--anchors-pack",anchorsPack],
        prompt: "Run export preflight now?",
        steps: &wizardSteps,
        status: &wizardStatus
      )

      print("\nStep 5) Asset exports (recommended)")
      print("Your repository still contains placeholder or missing assets.")
      print("This will use UI automation in Ableton and may overwrite placeholders.\n")

      // Pre-step: validate anchors if pack looks unset (skippable)
      let packLooksUnset = anchorsPack.contains("<pack_id>") || anchorsPack.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      if packLooksUnset {
        print("No anchors pack detected. UI automation will be brittle without anchors.\n")
        _ = await wizardRunStep(
          id: "validate_anchors",
          command: [hv,"validate-anchors","--regions-config","tools/automation/swift-cli/config/regions.v1.json","--pack",anchorsPack],
          prompt: "Run Validate Anchors now?",
          steps: &wizardSteps,
          status: &wizardStatus
        )
      } else {
        wizardSteps.append(WizardStep(id: "validate_anchors", command: "validate-anchors", exitCode: nil, decision: "skip", notes: "anchors pack present"))
      }

      print("Choose an option:")
      print("  [1] Export ALL (recommended)")
      print("  [2] Export step-by-step (guided)")
      print("  [3] Print commands only")
      print("  [s] Skip for now")
      print("> ", terminator: "")
      let choice = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

      switch choice {
      case "1":
        let ok = await wizardRunStep(id: "export_all",
                                     command: [hv,"assets","export-all","--anchors-pack",anchorsPack,"--overwrite"],
                                     prompt: "Proceed with Export ALL now?",
                                     steps: &wizardSteps,
                                     status: &wizardStatus)
        if ok { cfg.artifactExportsCompleted = true }
      case "2":
        let subs: [(String,[String])] = [
          ("export_racks", [hv,"assets","export-racks","--anchors-pack",anchorsPack,"--overwrite","ask"]),
          ("export_performance_set", [hv,"assets","export-performance-set","--anchors-pack",anchorsPack,"--overwrite"]),
          ("export_finishing_bays", [hv,"assets","export-finishing-bays","--anchors-pack",anchorsPack,"--overwrite"]),
          ("export_serum_base", [hv,"assets","export-serum-base","--anchors-pack",anchorsPack,"--overwrite"]),
          ("export_extras", [hv,"assets","export-extras","--anchors-pack",anchorsPack,"--overwrite"])
        ]
        for (sid, cmd) in subs {
          let ok = await wizardRunStep(id: sid,
                                       command: cmd,
                                       prompt: "Run " + sid.replacingOccurrences(of: "_", with: " ") + "?",
                                       steps: &wizardSteps,
                                       status: &wizardStatus)
          if ok { cfg.artifactExportsCompleted = true }
        }
      case "3":
        let cmdText = "hvlien assets export-all --anchors-pack \(anchorsPack) --overwrite"
        wizardSteps.append(WizardStep(id: "print_commands", command: cmdText, exitCode: nil, decision: "yes", notes: "printed"))
        print("\nCommands:\n" + cmdText + "\n")
        sawSkip = true
      default:
        wizardSteps.append(WizardStep(id: "asset_exports", command: "exports", exitCode: nil, decision: "skip", notes: "user_skipped"))
        print("Skipping asset exports for now.")
        sawSkip = true
      }

      if cfg.artifactExportsCompleted == true {
        _ = await wizardRunStep(id: "index_rebuild",
                                command: [hv,"index","build"],
                                prompt: "Rebuild index now?",
                                steps: &wizardSteps,
                                status: &wizardStatus)
      }
    } else {
      wizardSteps.append(WizardStep(id: "asset_exports", command: "exports", exitCode: nil, decision: "skip", notes: "no_pending_artifacts"))
    }

    if sawSkip && wizardStatus == "pass" { wizardStatus = "warn" }
    let ts = ISO8601DateFormatter().string(from: Date())
    let receipt = WizardReceiptV1(schemaVersion: 1,
                                  runId: wizardRunId,
                                  timestamp: ts,
                                  status: wizardStatus,
                                  steps: wizardSteps,
                                  anchorsPack: anchorsPack,
                                  notes: wizardNotes)
    writeWizardReceipt(runId: wizardRunId, receipt: receipt)

    cfg.firstRunCompleted = true
    try cfg.save(atRepoRoot: repoRoot)

    print("\nWizard complete. Launching Operator Shell…")
    print("Press Enter to continue…", terminator: "")
    _ = readLine()
  }

  private func confirm(_ prompt: String) async -> Bool {
    print(prompt + " [y/N] ", terminator: "")
    let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    return ans == "y" || ans == "yes"
  }

  private struct WizardReceiptV1: Codable {
    let schemaVersion: Int
    let runId: String
    let timestamp: String
    let status: String
    let steps: [WizardStep]
    let anchorsPack: String?
    let notes: [String]

    enum CodingKeys: String, CodingKey {
      case schemaVersion = "schema_version"
      case runId = "run_id"
      case timestamp
      case status
      case steps
      case anchorsPack = "anchors_pack"
      case notes
    }
  }

  private struct WizardStep: Codable {
    let id: String
    let command: String
    let exitCode: Int?
    let decision: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
      case id, command
      case exitCode = "exit_code"
      case decision
      case notes
    }
  }

  private func writeWizardReceipt(runId: String, receipt: WizardReceiptV1) {
    let dir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let path = dir.appendingPathComponent("wizard_receipt.v1.json")
    if let data = try? JSONEncoder().encode(receipt) {
      try? data.write(to: path, options: [.atomic])
    }
  }

  private func wizardRunStep(id: String,
                             command: [String],
                             prompt: String,
                             steps: inout [WizardStep],
                             status: inout String) async -> Bool {
    print(prompt + " [y/N] ", terminator: "")
    let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    let yes = (ans == "y" || ans == "yes")
    let cmdStr = command.joined(separator: " ")
    if !yes {
      steps.append(WizardStep(id: id, command: cmdStr, exitCode: nil, decision: "no", notes: nil))
      return false
    }
    let exit = (try? await runProcess(command)) ?? 999
    steps.append(WizardStep(id: id, command: cmdStr, exitCode: Int(exit), decision: "yes", notes: nil))
    if exit != 0 { status = "fail" }
    return exit == 0
  }

  private func detectPendingArtifacts() -> Bool {
    let idx = "checksums/index/artifact_index.v1.json"
    guard FileManager.default.fileExists(atPath: idx),
          let data = try? Data(contentsOf: URL(fileURLWithPath: idx)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let arts = obj["artifacts"] as? [[String: Any]] else {
      return true
    }
    for a in arts {
      if let st = a["status"] as? [String: Any],
         let state = st["state"] as? String,
         (state == "missing" || state == "placeholder") {
        return true
      }
    }
    return false
  }

  private struct DisplayCheckResult {
    let info: String?
    let warning: String?
  }

  private func displayTargetCheck(anchorsPack: String) -> DisplayCheckResult {
    guard let screen = NSScreen.main else { return .init(info: nil, warning: "no main display detected") }
    let size = screen.frame.size
    let width = Int(size.width)
    let height = Int(size.height)
    let info = "\(width)x\(height) main"

    if anchorsPack.contains("<pack_id>") || anchorsPack.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return .init(info: info, warning: "anchors-pack not set; UI targets may be wrong")
    }

    if anchorsPack.contains("2560x1440") {
      if width != 2560 || height != 1440 {
        return .init(info: info, warning: "anchors pack is 2560x1440 but main display is \(width)x\(height)")
      }
    } else if anchorsPack.contains("5k_morespace") {
      // Apple Studio Display 'More Space' typically reports 3200x1800 points.
      if width != 3200 || height != 1800 {
        return .init(info: info, warning: "anchors pack is 5k_morespace but main display is \(width)x\(height)")
      }
    }

    return .init(info: info, warning: nil)
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
