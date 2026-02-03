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
    let hv = resolveWubBinary(repoRoot: repoRoot) ?? "wub"

    let allItems: [MenuItem] = buildMenu(hv: hv, anchorsPack: ap)

    // UI modes
    var voiceMode = false           // minimizes letters/keys, emphasizes numbers
    var studioMode = true           // hide risky commands by default
    var showAll = false             // GUIDED/ALL view (when studioMode is off, this is the normal toggle)
    var selected = 0

    // transient state
    let runner = RunnerState()
    let toast = ToastState()
    var logScroll = 0
    var showHelp = false

    while true {
      toast.tick()
      // dynamic filtered view
      let items = visibleItems(all: allItems, studioMode: studioMode, showAll: showAll)
      selected = min(selected, max(0, items.count - 1))

      runner.lastRunDir = latestRunDir()
      runner.lastFailuresDir = latestFailuresDir(inRunDir: runner.lastRunDir)

      let snapshot = StudioStateEvaluator.evaluate(config: .init(
        repoRoot: repoRoot,
        runsDir: "runs",
        anchorsPack: cfg.anchorsPack,
        now: Date(),
        sweepStaleSeconds: 60 * 30,
        readyStaleSeconds: 60 * 30
      ))
      let logLines = runner.logBuffer.window(count: 20, scroll: logScroll)
      let rec = RecommendedAction(
        summary: snapshot.recommended.summary,
        action: snapshot.recommended.command.map {
          .init(command: $0, danger: snapshot.recommended.danger, label: $0.joined(separator: " "))
        }
      )
      let displayCheck = displayTargetCheck(anchorsPack: ap)

      let confirming: Bool
      if case .confirming = runner.state { confirming = true } else { confirming = false }
      let context = ShellContext(showLogs: runner.showLogs,
                                 confirming: confirming,
                                 studioMode: studioMode,
                                 showAll: showAll,
                                 voiceMode: voiceMode,
                                 showHelp: showHelp)
      let legendLine = LegendRenderer.render(context: context)
      let helpLines = HelpOverlayRenderer.render(context: context)
      printScreen(repoRoot: repoRoot,
                  hv: hv,
                  anchorsPack: ap,
                  displayInfo: displayCheck.info,
                  displayWarning: displayCheck.warning,
                  voiceMode: voiceMode,
                  studioMode: studioMode,
                  showAll: showAll,
                  lastRun: runner.lastRunDir,
                  failuresDir: runner.lastFailuresDir,
                  snapshot: snapshot,
                  toastLine: toast.currentText,
                  showLogs: runner.showLogs,
                  logLines: logLines,
                  confirming: confirming,
                  showHelp: showHelp,
                  legendLine: legendLine,
                  helpLines: helpLines,
                  items: items,
                  selected: selected,
                  lastExit: runner.lastExit,
                  lastReceipt: runner.lastReceiptPath)

      let key = InputDecoder.readKey(timeoutMs: runner.state == .running ? 100 : 250)
      let action = ActionRouter.route(key, context: context)
      switch action {
      case .quit:
        return

      case .toggleVoice:
        voiceMode.toggle()
        toast.info(voiceMode ? "Voice mode enabled — say or press numbers" : "Voice mode disabled", key: "voice_toggle")
        continue

      case .toggleSafe:
        studioMode.toggle()
        selected = 0
        toast.info(studioMode ? "Safe mode — risky actions hidden" : "Guided mode — essential actions visible", key: "studio_toggle")
        continue

      case .toggleView:
        if studioMode {
          toast.blocked("View is locked in SAFE — press s to reveal guided actions", key: "view_locked_safe")
          continue
        }
        showAll.toggle()
        selected = 0
        toast.info(showAll ? "All actions visible" : "Guided mode — essential actions only", key: "view_toggle")
        continue
      case .toggleLogs:
        runner.showLogs.toggle()
        logScroll = 0
        toast.info(runner.showLogs ? "Logs opened" : "Logs hidden", key: "logs_toggle")
        continue
      case .back:
        if runner.showLogs {
          runner.showLogs = false
          toast.info("Back to actions", key: "logs_back")
          continue
        }
        continue
      case .bottom:
        if runner.showLogs {
          logScroll = 0
          toast.info("Jumped to bottom", key: "logs_bottom", ttl: 1.0)
          continue
        }
        continue

      case .refresh:
        continue

      case .moveUp:
        if runner.showLogs {
          logScroll = min(logScroll + 1, max(0, runner.logBuffer.lines.count - 1))
        } else {
          selected = max(0, selected - 1)
        }

      case .moveDown:
        if runner.showLogs {
          logScroll = max(0, logScroll - 1)
        } else {
          selected = min(items.count - 1, selected + 1)
        }

      case .previewDriftPlan:
        startAction(.init(command: [hv, "drift", "plan", "--anchors-pack-hint", ap], danger: false, label: "Drift: plan"),
                    runner: runner, toast: toast, dryRun: dryRun)

      case .readyVerify:
        startAction(.init(command: [hv, "ready", "--anchors-pack-hint", ap], danger: false, label: "Ready: verify"),
                    runner: runner, toast: toast, dryRun: dryRun)

      case .repairRun:
        startAction(.init(command: [hv, "repair", "--anchors-pack-hint", ap], danger: true, label: "Repair: run recipe"),
                    runner: runner, toast: toast, dryRun: dryRun)

      case .runNext:
        if let action = rec.action {
          if action.danger && studioMode {
            toast.blocked("Next action is risky and hidden — press s to proceed", key: "next_hidden_safe")
            continue
          }
          if case .running = runner.state {
            toast.info("Action running — wait", key: "action_running")
            continue
          }
          if case .confirming = runner.state {
            toast.info("Confirmation pending", key: "action_confirm_pending")
            continue
          }
          startAction(action, runner: runner, toast: toast, dryRun: dryRun)
        } else {
          toast.info("No pending actions — studio is ready", key: "no_next_action", ttl: 1.8)
        }
        continue

      case .runSelected:
        let item = items[selected]
        if case .running = runner.state {
          toast.info("Action running — wait", key: "action_running")
          continue
        }
        if case .confirming = runner.state {
          toast.info("Confirmation pending", key: "action_confirm_pending")
          continue
        }
        startAction(.init(command: item.command, danger: item.danger, label: item.title),
                    runner: runner, toast: toast, dryRun: dryRun)

      case .openReceipt:
        if let rp = runner.lastReceiptPath {
          _ = try? await OperatorShellService.openPath(rp)
          toast.success("Opened receipt", key: "open_receipt_ok")
        } else {
          toast.blocked("No receipt recorded yet", key: "open_receipt_missing")
        }
      case .openRun:
        if let rd = runner.lastRunDir {
          _ = try? await OperatorShellService.openPath(rd)
          toast.success("Opened run folder", key: "open_run_ok")
        } else {
          toast.blocked("No run folder yet", key: "open_run_missing")
        }
      case .openFailures:
        if let fd = runner.lastFailuresDir {
          _ = try? await OperatorShellService.openPath(fd)
          toast.success("Opened failures folder", key: "open_fail_ok")
        } else {
          toast.blocked("No failures folder for last run", key: "open_fail_missing")
        }

      case .selectNumber(let n):
        // Voice Mode: allow direct numeric selection ("press 3")
        if n >= 1 && n <= items.count {
          selected = n - 1
          let item = items[selected]
          if case .running = runner.state {
            toast.info("Action running — wait", key: "action_running")
            continue
          }
          if case .confirming = runner.state {
            toast.info("Confirmation pending", key: "action_confirm_pending")
            continue
          }
          startAction(.init(command: item.command, danger: item.danger, label: item.title),
                      runner: runner, toast: toast, dryRun: dryRun)
        } else {
          toast.info("No action at that number", key: "no_action_number")
        }
      case .confirmYes:
        if case .confirming(let action) = runner.state {
          beginRun(action, runner: runner, toast: toast, dryRun: dryRun)
        }
      case .confirmNo:
        if case .confirming = runner.state {
          runner.state = .idle
          toast.info("Action cancelled — studio state unchanged", key: "danger_cancel", ttl: 1.8)
        }
      case .toggleHelp:
        showHelp.toggle()
      case .none:
        continue
      }
    }
  }

  // MARK: Menu & modes

  enum RunState: Equatable {
    case idle
    case confirming(RecommendedAction.Action)
    case running(RecommendedAction.Action)
  }

  final class RunnerState {
    var state: RunState = .idle
    var process: Process?
    var partialOutput: String = ""
    var logBuffer = LogBuffer()
    var lastExit: Int32? = nil
    var lastReceiptPath: String? = nil
    var lastRunDir: String? = nil
    var lastFailuresDir: String? = nil
    var showLogs: Bool = false
  }

  final class ToastState {
    var manager = ToastManager()

    func tick() { manager.tick() }
    var currentText: String? { manager.currentText }
    func info(_ msg: String, key: String, ttl: TimeInterval = 1.5) { manager.info(msg, key: key, ttl: ttl) }
    func success(_ msg: String, key: String, ttl: TimeInterval = 1.2) { manager.success(msg, key: key, ttl: ttl) }
    func blocked(_ msg: String, key: String, ttl: TimeInterval = 2.5) { manager.blocked(msg, key: key, ttl: ttl) }
  }

  struct MenuItem {
    let title: String
    let command: [String]
    let danger: Bool
    let category: String
    let isGuided: Bool
  }

  func buildMenu(hv: String, anchorsPack: String) -> [MenuItem] {
    [
      .init(title: "Preflight (first run)", command: [hv, "preflight", "--auto"], danger: false, category: "Onboarding", isGuided: true),
      .init(title: "Select Anchors Pack…", command: [hv, "anchors", "select"], danger: false, category: "Onboarding", isGuided: true),
      .init(title: "Sweep (modal guard)", command: [hv, "sweep", "--modal-test", "detect", "--allow-ocr-fallback"], danger: false, category: "Safety", isGuided: true),
      .init(title: "MIDI list", command: [hv, "midi", "list"], danger: false, category: "Runtime", isGuided: false),
      .init(title: "VRL validate", command: [hv, "vrl", "validate", "--mapping", WubDefaults.profileSpecPath("voice_runtime/v9_3_ableton_mapping.v1.yaml")], danger: false, category: "Runtime", isGuided: true),

      .init(title: "Assets: export ALL (repo completeness)", command: [hv, "assets", "export-all", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports", isGuided: true),
      .init(title: "Assets: export racks", command: [hv, "assets", "export-racks", "--anchors-pack", anchorsPack, "--overwrite", "ask"], danger: true, category: "Exports", isGuided: false),
      .init(title: "Assets: export performance set", command: [hv, "assets", "export-performance-set", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports", isGuided: false),
      .init(title: "Assets: export finishing bays", command: [hv, "assets", "export-finishing-bays", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports", isGuided: false),
      .init(title: "Assets: export serum base", command: [hv, "assets", "export-serum-base", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports", isGuided: false),
      .init(title: "Assets: export extras", command: [hv, "assets", "export-extras", "--anchors-pack", anchorsPack, "--overwrite"], danger: true, category: "Exports", isGuided: false),

      .init(title: "Index: build", command: [hv, "index", "build"], danger: false, category: "Index", isGuided: true),
      .init(title: "Index: status", command: [hv, "index", "status"], danger: false, category: "Index", isGuided: false),
      .init(title: "Drift: check", command: [hv, "drift", "check", "--anchors-pack-hint", anchorsPack], danger: false, category: "Drift", isGuided: true),
      .init(title: "Drift: plan", command: [hv, "drift", "plan", "--anchors-pack-hint", anchorsPack], danger: false, category: "Drift", isGuided: true),
      .init(title: "Drift: fix (guarded)", command: [hv, "drift", "fix", "--anchors-pack-hint", anchorsPack], danger: true, category: "Drift", isGuided: true),

      .init(title: "Ready: verify", command: [hv, "ready", "--anchors-pack-hint", anchorsPack], danger: false, category: "Governance", isGuided: true),
      .init(title: "Repair: run recipe (guarded)", command: [hv, "repair", "--anchors-pack-hint", anchorsPack], danger: true, category: "Governance", isGuided: true),
      .init(title: "Station: certify", command: [hv, "station", "certify"], danger: true, category: "Governance", isGuided: true),
      .init(title: "Open last report", command: ["bash","-lc", "open " + (latestReportPath() ?? "runs")], danger: false, category: "Open", isGuided: true),
      .init(title: "Open last run folder", command: ["bash","-lc", "open " + (latestRunDir() ?? "runs")], danger: false, category: "Open", isGuided: true),
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
      // Non-studio mode: GUIDED vs ALL
      if showAll { return all }
      return all.filter { $0.isGuided }
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

  func appendRunSummary(action: RecommendedAction.Action,
                        logBuffer: inout LogBuffer,
                        lastExit: Int32?,
                        lastRunDir: String?,
                        lastReceipt: String?) {
    if let exit = lastExit { logBuffer.append("exit: \(exit)") }
    if let rd = lastRunDir { logBuffer.append("run: \(rd)") }
    if let rp = lastReceipt { logBuffer.append("receipt: \(rp)") }
  }

  func startAction(_ action: RecommendedAction.Action,
                   runner: RunnerState,
                   toast: ToastState,
                   dryRun: Bool) {
    if action.danger && !dryRun {
      runner.state = .confirming(action)
      toast.blocked("This action modifies the studio state — confirmation required", key: "danger_confirm", ttl: 1.0)
      return
    }
    beginRun(action, runner: runner, toast: toast, dryRun: dryRun)
  }

  func beginRun(_ action: RecommendedAction.Action,
                runner: RunnerState,
                toast: ToastState,
                dryRun: Bool) {
    runner.logBuffer.append("> " + action.command.joined(separator: " "))
    runner.showLogs = true
    runner.state = .running(action)
    runner.partialOutput = ""

    if dryRun {
      runner.lastExit = 0
      runner.lastRunDir = latestRunDir()
      runner.lastReceiptPath = discoverLatestReceipt(inRunDir: runner.lastRunDir)
      runner.lastFailuresDir = latestFailuresDir(inRunDir: runner.lastRunDir)
      appendRunSummary(action: action,
                       logBuffer: &runner.logBuffer,
                       lastExit: runner.lastExit,
                       lastRunDir: runner.lastRunDir,
                       lastReceipt: runner.lastReceiptPath)
      runner.state = .idle
      toast.success("Completed successfully", key: "action_ok")
      return
    }

    do {
      runner.process = try StreamingProcess.start(args: action.command, onChunk: { chunk in
        let normalized = chunk.replacingOccurrences(of: "\r", with: "")
        runner.partialOutput.append(normalized)
        let parts = runner.partialOutput.split(separator: "\n", omittingEmptySubsequences: false)
        if parts.count > 1 {
          for line in parts.dropLast() {
            runner.logBuffer.append(String(line))
          }
          runner.partialOutput = String(parts.last ?? "")
        }
      }, onExit: { code in
        if !runner.partialOutput.isEmpty {
          runner.logBuffer.append(runner.partialOutput)
          runner.partialOutput = ""
        }
        runner.lastExit = code
        runner.lastRunDir = self.latestRunDir()
        runner.lastReceiptPath = self.discoverLatestReceipt(inRunDir: runner.lastRunDir)
        runner.lastFailuresDir = self.latestFailuresDir(inRunDir: runner.lastRunDir)
        self.appendRunSummary(action: action,
                              logBuffer: &runner.logBuffer,
                              lastExit: runner.lastExit,
                              lastRunDir: runner.lastRunDir,
                              lastReceipt: runner.lastReceiptPath)
        runner.state = .idle
        if code == 0 {
          toast.success("Completed successfully", key: "action_ok")
        } else {
          let tail = runner.lastRunDir ?? "runs/<id>/"
          toast.blocked("Action failed — see \(tail) for details", key: "action_fail")
        }
      })
    } catch {
      runner.state = .idle
      toast.blocked("Action failed to start — see logs", key: "action_start_fail")
    }
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
                   snapshot: StudioStateSnapshot,
                   toastLine: String?,
                   showLogs: Bool,
                   logLines: [String],
                   confirming: Bool,
                   showHelp: Bool,
                   legendLine: String,
                   helpLines: [String],
                   items: [MenuItem],
                   selected: Int,
                   lastExit: Int32?,
                   lastReceipt: String?) {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    let stationLine = StationBarRender.renderLine(label: "STATION", gates: snapshot.gates, next: snapshot.recommended.command?.joined(separator: " "))
    print(stationLine)
    let modeLabel = studioMode ? "SAFE" : (showAll ? "ALL" : "GUIDED")
    let viewLabel = studioMode ? "locked" : (showAll ? "ALL" : "GUIDED")
    let total = allItemsCount(anchorsPack: anchorsPack, hv: hv)
    let visible = items.count
    print("mode: \(modeLabel) (\(visible)/\(total))   view: \(viewLabel)\(studioMode ? "" : " (a)")")
    if studioMode {
      print("SAFE hides risky actions (exports/fix/repair/certify)")
    }
    if let ap = snapshot.anchorsPack {
      print("Anchors: \(ap)    Last: \(lastRun ?? "—")")
    } else {
      print("Anchors: NOT SET    Last: \(lastRun ?? "—")")
    }
    if let info = displayInfo { print("display: \(info)") }
    if let warn = displayWarning { print("display warning: \(warn)") }
    if let fd = failuresDir { print("last failures: \(fd)") }
    if let e = lastExit { print("last exit: \(e)") }
    if let r = lastReceipt { print("last receipt: \(r)") }

    print(String(repeating: "-", count: 88))
    if showHelp {
      for line in helpLines { print(line) }
      return
    }
    if let tl = toastLine { print(tl) }
    print(legendLine)
    if voiceMode { print("voice hint: Say \"press 3\" (then Enter) or use number keys 1-9.") }
    print(String(repeating: "-", count: 88))

    if showLogs {
      print("LOG  (last run)")
      for line in logLines { print(line) }
      if confirming {
        print("confirm: This action modifies studio state. Proceed?  (y)es / (n)o")
      } else if let tl = toastLine {
        print(tl)
      }
    } else {
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
      if confirming {
        print("confirm: This action modifies studio state. Proceed?  (y)es / (n)o")
      } else if let tl = toastLine {
        print(tl)
      }
    }
  }

  func allItemsCount(anchorsPack: String, hv: String) -> Int {
    return buildMenu(hv: hv, anchorsPack: anchorsPack).count
  }

  // MARK: FS helpers

  func latestRunDir() -> String? {
    OperatorShellService.latestRunDirPath(runsDir: "runs")
  }

  func latestFailuresDir(inRunDir runDir: String?) -> String? {
    if let rd = runDir {
      let p = URL(fileURLWithPath: rd).appendingPathComponent("failures", isDirectory: true).path
      if FileManager.default.fileExists(atPath: p) { return p }
    }
    return OperatorShellService.findFailures(in: "runs")
  }

  func latestReportPath() -> String? {
    OperatorShellService.findReport(in: "runs")
  }

  func discoverLatestReceipt(inRunDir runDir: String?) -> String? {
    guard let rd = runDir else { return nil }
    return OperatorShellService.findReceipt(in: rd)
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
    if args.first == "wub" { args[0] = hv }
    let danger = cmd.contains("export-all") || cmd.contains("drift fix") || cmd.contains("assets export")
    return .init(command: args, danger: danger, label: cmd)
  }

  func resolveWubBinary(repoRoot: String) -> String? {
    let p1 = URL(fileURLWithPath: repoRoot).appendingPathComponent("tools/automation/swift-cli/.build/release/wub").path
    return FileManager.default.isExecutableFile(atPath: p1) ? p1 : nil
  }

  func runProcess(_ args: [String]) async throws -> Int32 {
    try await OperatorShellService.runProcess(args)
  }

  // MARK: First-run wizard
  private func runFirstRunWizard(repoRoot: String,
                                 hv: String,
                                 anchorsPack: String,
                                 cfg: inout LocalConfig) async throws {
    // Wizard runs in cooked mode (outside raw-key loop).
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    print("WUB First-Run Wizard (v1.7.15)")
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
    print("  2) DubSweeper (permissions + modal sweep)")
    print("  3) Index build (v1.8)")
    print("\nYou can skip any step. Nothing runs without confirmation.\n")

    _ = await wizardRunStep(id: "build",
                            command: ["bash","-lc","cd tools/automation/swift-cli && swift build -c release"],
                            prompt: "Run build now? (swift build -c release)",
                            steps: &wizardSteps,
                            status: &wizardStatus)
    _ = await wizardRunStep(id: "sweep",
                            command: [hv,"sweep","--modal-test","detect","--allow-ocr-fallback"],
                            prompt: "Run sweep check now?",
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
        let cmdText = "wub assets export-all --anchors-pack \(anchorsPack) --overwrite"
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
