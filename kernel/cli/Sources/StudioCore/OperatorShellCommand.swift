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

    let ap = cfg.anchorsPack ?? "shared/specs/automation/anchors/<pack_id>"
    let wubBin = resolveWubBinary(repoRoot: repoRoot) ?? "wub"

    let allItems: [MenuItem] = buildMenu(wubBin: wubBin, anchorsPack: ap, showPreflight: (cfg.firstRunCompleted ?? false) == false)

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
        sweepStaleSeconds: 60 * 10,
        readyStaleSeconds: 60 * 10
      ))
      let allGatesPass = snapshot.gates.allSatisfy { $0.status == .pass }
      if (cfg.firstRunCompleted ?? false) == false && allGatesPass {
        cfg.firstRunCompleted = true
        try? cfg.save(atRepoRoot: repoRoot)
      }
      let logLines = runner.logBuffer.window(count: 20, scroll: logScroll)
      let rec = RecommendedAction(
        summary: snapshot.recommended.summary,
        action: snapshot.recommended.command.map {
          var cmd = $0
          if let first = cmd.first, first == "wub" { cmd[0] = wubBin }
          return .init(command: cmd, danger: snapshot.recommended.danger, label: cmd.joined(separator: " "))
        }
      )
      let displayCheck = displayTargetCheck(anchorsPack: ap)
      let recommendedVisible: Bool
      if let action = rec.action {
        recommendedVisible = items.contains(where: { $0.command == action.command })
      } else {
        recommendedVisible = true
      }
      let noteLine: String?
      if let action = rec.action, studioMode && action.danger {
        noteLine = "note: next action is risky and hidden in SAFE — press s"
      } else if let _ = rec.action, !studioMode && !showAll && !recommendedVisible {
        noteLine = "note: next action not shown in GUIDED — press a for ALL"
      } else {
        noteLine = nil
      }
      if Date().timeIntervalSince(runner.lastStationCheck) > 5 && !runner.stationStatusInFlight {
        runner.stationStatusInFlight = true
        stationSummaryAsync(wubBin: wubBin, timeoutMs: 600) { summary in
          runner.lastStationSummary = summary
          runner.lastStationCheck = Date()
          runner.stationStatusInFlight = false
        }
      }
      let currentStatuses = Dictionary(uniqueKeysWithValues: snapshot.gates.map { ($0.key, $0.status) })
      if !runner.lastGateStatuses.isEmpty {
        for g in snapshot.gates {
          let prev = runner.lastGateStatuses[g.key]
          if prev != g.status && g.status == .pass {
            switch g.key {
            case "A": toast.success("Anchors configured", key: "gate_a_pass")
            case "S": toast.success("Sweep passed — no blocking modals detected", key: "gate_s_pass")
            case "I": toast.success("Index built", key: "gate_i_pass")
            case "F": toast.success("Artifacts generated", key: "gate_f_pass")
            case "R": toast.success("Studio ready", key: "gate_r_pass")
            default: break
            }
          }
        }
      }
      if allGatesPass && runner.lastAllGatesPass == false {
        toast.success("Studio ready (CLEARED)", key: "studio_cleared", ttl: 1.8)
      }
      runner.lastAllGatesPass = allGatesPass
      runner.lastGateStatuses = currentStatuses

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
                  wubBin: wubBin,
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
                  noteLine: noteLine,
                  stationSummary: runner.lastStationSummary,
                  items: items,
                  selected: selected,
                  lastExit: runner.lastExit,
                  lastReceipt: runner.lastReceiptPath,
                  showPreflight: (cfg.firstRunCompleted ?? false) == false)

      let isRunning: Bool
      if case .running = runner.state { isRunning = true } else { isRunning = false }
      let key = InputDecoder.readKey(timeoutMs: isRunning ? 100 : 250)
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
        startAction(.init(command: [wubBin, "drift", "plan", "--anchors-pack-hint", ap], danger: false, label: "Drift: plan"),
                    runner: runner, toast: toast, dryRun: dryRun)

      case .readyVerify:
        startAction(.init(command: [wubBin, "ready", "--anchors-pack-hint", ap], danger: false, label: "Ready: verify"),
                    runner: runner, toast: toast, dryRun: dryRun)

      case .repairRun:
        startAction(.init(command: [wubBin, "repair", "--anchors-pack-hint", ap], danger: true, label: "Repair: run recipe"),
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
      case .openReport:
        if let report = latestReportPath() {
          _ = try? await OperatorShellService.openPath(report)
          toast.success("Opened report", key: "open_report_ok")
        } else {
          toast.blocked("No report recorded yet", key: "open_report_missing")
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

  enum RunState {
    case idle
    case confirming(RecommendedAction.Action)
    case running(RecommendedAction.Action)
  }

  final class RunnerState {
    var state: RunState = .idle
    var lastStationSummary: String = "unk."
    var lastStationCheck: Date = Date.distantPast
    var stationStatusInFlight: Bool = false
    var lastGateStatuses: [String: GateStatus] = [:]
    var lastAllGatesPass: Bool = false
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
    let explain: [String]
  }

  func buildMenu(wubBin: String, anchorsPack: String, showPreflight: Bool) -> [MenuItem] {
    var items: [MenuItem] = []
    if showPreflight {
      let title = "Preflight (first run)"
      items.append(.init(title: title,
                         command: [wubBin, "preflight", "--auto"],
                         danger: false,
                         category: "Onboarding",
                         isGuided: true,
                         explain: explainLines(title: title, category: "Onboarding")))
    }
    do {
      let title = "Select Anchors Pack…"
      items.append(.init(title: title,
                         command: [wubBin, "anchors", "select"],
                         danger: false,
                         category: "Onboarding",
                         isGuided: true,
                         explain: explainLines(title: title, category: "Onboarding")))
    }

    items += [
      {
        let title = "Sweep (modal guard)"
        return .init(title: title,
                     command: [wubBin, "sweep", "--modal-test", "detect", "--allow-ocr-fallback"],
                     danger: false,
                     category: "Safety",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Safety"))
      }(),
      {
        let title = "MIDI list"
        return .init(title: title,
                     command: [wubBin, "midi", "list"],
                     danger: false,
                     category: "Runtime",
                     isGuided: false,
                     explain: explainLines(title: title, category: "Runtime"))
      }(),
      {
        let title = "VRL validate"
        return .init(title: title,
                     command: [wubBin, "vrl", "validate", "--mapping", WubDefaults.profileSpecPath("voice/runtime/vrl_mapping.v1.yaml")],
                     danger: false,
                     category: "Runtime",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Runtime"))
      }(),
      {
        let title = "Assets: export ALL (repo completeness)"
        return .init(title: title,
                     command: [wubBin, "assets", "export-all", "--anchors-pack", anchorsPack, "--overwrite"],
                     danger: true,
                     category: "Exports",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Exports"))
      }(),
      {
        let title = "Assets: export racks"
        return .init(title: title,
                     command: [wubBin, "assets", "export-racks", "--anchors-pack", anchorsPack, "--overwrite", "ask"],
                     danger: true,
                     category: "Exports",
                     isGuided: false,
                     explain: explainLines(title: title, category: "Exports"))
      }(),
      {
        let title = "Assets: export performance set"
        return .init(title: title,
                     command: [wubBin, "assets", "export-performance-set", "--anchors-pack", anchorsPack, "--overwrite"],
                     danger: true,
                     category: "Exports",
                     isGuided: false,
                     explain: explainLines(title: title, category: "Exports"))
      }(),
      {
        let title = "Assets: export finishing bays"
        return .init(title: title,
                     command: [wubBin, "assets", "export-finishing-bays", "--anchors-pack", anchorsPack, "--overwrite"],
                     danger: true,
                     category: "Exports",
                     isGuided: false,
                     explain: explainLines(title: title, category: "Exports"))
      }(),
      {
        let title = "Assets: export serum base"
        return .init(title: title,
                     command: [wubBin, "assets", "export-serum-base", "--anchors-pack", anchorsPack, "--overwrite"],
                     danger: true,
                     category: "Exports",
                     isGuided: false,
                     explain: explainLines(title: title, category: "Exports"))
      }(),
      {
        let title = "Assets: export extras"
        return .init(title: title,
                     command: [wubBin, "assets", "export-extras", "--anchors-pack", anchorsPack, "--overwrite"],
                     danger: true,
                     category: "Exports",
                     isGuided: false,
                     explain: explainLines(title: title, category: "Exports"))
      }(),
      {
        let title = "Index: build"
        return .init(title: title,
                     command: [wubBin, "index", "build"],
                     danger: false,
                     category: "Index",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Index"))
      }(),
      {
        let title = "Index: status"
        return .init(title: title,
                     command: [wubBin, "index", "status"],
                     danger: false,
                     category: "Index",
                     isGuided: false,
                     explain: explainLines(title: title, category: "Index"))
      }(),
      {
        let title = "Drift: check"
        return .init(title: title,
                     command: [wubBin, "drift", "check", "--anchors-pack-hint", anchorsPack],
                     danger: false,
                     category: "Drift",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Drift"))
      }(),
      {
        let title = "Drift: plan"
        return .init(title: title,
                     command: [wubBin, "drift", "plan", "--anchors-pack-hint", anchorsPack],
                     danger: false,
                     category: "Drift",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Drift"))
      }(),
      {
        let title = "Drift: fix (guarded)"
        return .init(title: title,
                     command: [wubBin, "drift", "fix", "--anchors-pack-hint", anchorsPack],
                     danger: true,
                     category: "Drift",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Drift"))
      }(),
      {
        let title = "Ready: verify"
        return .init(title: title,
                     command: [wubBin, "ready", "--anchors-pack-hint", anchorsPack],
                     danger: false,
                     category: "Governance",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Governance"))
      }(),
      {
        let title = "Repair: run recipe (guarded)"
        return .init(title: title,
                     command: [wubBin, "repair", "--anchors-pack-hint", anchorsPack],
                     danger: true,
                     category: "Governance",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Governance"))
      }(),
      {
        let title = "Station: certify"
        return .init(title: title,
                     command: [wubBin, "station", "certify"],
                     danger: true,
                     category: "Governance",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Governance"))
      }(),
      {
        let title = "Open last report"
        return .init(title: title,
                     command: ["bash","-lc", "open " + (latestReportPath() ?? "runs")],
                     danger: false,
                     category: "Open",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Open"))
      }(),
      {
        let title = "Open last run folder"
        return .init(title: title,
                     command: ["bash","-lc", "open " + (latestRunDir() ?? "runs")],
                     danger: false,
                     category: "Open",
                     isGuided: true,
                     explain: explainLines(title: title, category: "Open"))
      }()
    ]

    return items
  }

  func explainLines(title: String, category: String) -> [String] {
    switch title {
    case "Preflight (first run)":
      return [
        "When: first run or environment changes.",
        "Prereqs: none.",
        "Outputs: readiness summary + blockers.",
        "Recovery: follow the next action."
      ]
    case "Select Anchors Pack…":
      return [
        "When: anchors pack is missing or stale.",
        "Prereqs: packs present under shared/specs/automation/anchors.",
        "Outputs: saves anchors pack to local config.",
        "Recovery: re-run if UI automation fails."
      ]
    case "Open last report":
      return [
        "When: review the latest report output.",
        "Prereqs: at least one report run.",
        "Outputs: opens report file in runs/<id>/...",
        "Recovery: run a report command to regenerate."
      ]
    case "Open last run folder":
      return [
        "When: inspect receipts/logs for the latest run.",
        "Prereqs: at least one run exists.",
        "Outputs: opens runs/<id>/ folder.",
        "Recovery: run any command to create a run."
      ]
    default:
      break
    }

    switch category {
    case "Safety":
      return [
        "When: before automation if UI may block.",
        "Prereqs: anchors pack configured.",
        "Outputs: sweep report under runs/<id>/...",
        "Recovery: close modals, then re-run sweep."
      ]
    case "Runtime":
      return [
        "When: validating runtime setup or mappings.",
        "Prereqs: mapping files present.",
        "Outputs: validation output or device list.",
        "Recovery: fix mapping/device issues and re-run."
      ]
    case "Exports":
      return [
        "When: artifacts missing or placeholders exist.",
        "Prereqs: anchors pack + sweep pass.",
        "Outputs: export receipts + updated assets.",
        "Recovery: re-run export-all for missing categories."
      ]
    case "Index":
      return [
        "When: after exporting or editing assets.",
        "Prereqs: artifacts present on disk.",
        "Outputs: checksums/index/artifact_index.v1.json.",
        "Recovery: re-run index build."
      ]
    case "Drift":
      return [
        "When: before certification or release.",
        "Prereqs: index exists.",
        "Outputs: drift report under runs/<id>/...",
        "Recovery: run drift fix if required."
      ]
    case "Governance":
      return [
        "When: verifying readiness or repairing state.",
        "Prereqs: anchors, sweep, index, artifacts.",
        "Outputs: ready report or repair receipts.",
        "Recovery: follow recommended next action."
      ]
    case "Open":
      return [
        "When: inspect recent receipts and logs.",
        "Prereqs: runs/<id>/ exists.",
        "Outputs: opens target path.",
        "Recovery: run any command to create a run."
      ]
    default:
      return [
        "When: run as needed.",
        "Prereqs: see command details.",
        "Outputs: receipts/logs under runs/<id>/...",
        "Recovery: follow recommended next action."
      ]
    }
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
          toast.blocked("Action failed — see \(tail) for details. Next: wub check", key: "action_fail")
        }
      })
    } catch {
      runner.state = .idle
      toast.blocked("Action failed to start — see logs. Next: wub check", key: "action_start_fail")
    }
  }

  // MARK: render

  func printScreen(repoRoot: String,
                   wubBin: String,
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
                   noteLine: String?,
                   stationSummary: String,
                   items: [MenuItem],
                   selected: Int,
                   lastExit: Int32?,
                   lastReceipt: String?,
                   showPreflight: Bool) {
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    let width = Int(ProcessInfo.processInfo.environment["COLUMNS"] ?? "100") ?? 100
    let stationLine = renderStationLine(snapshot: snapshot, width: width)
    print(stationLine)
    let modeLabel = studioMode ? "SAFE" : (showAll ? "ALL" : "GUIDED")
    let viewLabel = studioMode ? "locked" : (showAll ? "ALL" : "GUIDED")
    let total = allItemsCount(anchorsPack: anchorsPack, wubBin: wubBin, showPreflight: showPreflight)
    let visible = items.count
    let modeLine = "mode: \(modeLabel) (\(visible)/\(total))   view: \(viewLabel)\(studioMode ? "" : " (a)")"
    print(truncateTail(modeLine, maxLen: width))
    let anchorMax = max(18, Int(Double(width) * 0.45))
    let lastMax = max(14, Int(Double(width) * 0.30))
    if let ap = snapshot.anchorsPack {
      let apText = truncatePath(ap, maxLen: anchorMax, repoRoot: repoRoot)
      let lastText = truncateTail(lastRun ?? "—", maxLen: lastMax)
      let line3 = "Anchors: \(apText)    Station: \(stationSummary)    Last: \(lastText)"
      print(truncateTail(line3, maxLen: width))
    } else {
      let lastText = truncateTail(lastRun ?? "—", maxLen: lastMax)
      let line3 = "Anchors: NOT SET    Station: \(stationSummary)    Last: \(lastText)"
      print(truncateTail(line3, maxLen: width))
    }
    if let info = displayInfo { print("display: \(info)") }
    if let note = noteLine {
      print(truncateTail(note, maxLen: width))
    } else if let detail = firstFailDetailLine(snapshot: snapshot) {
      print(truncateTail(detail, maxLen: width))
    }
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
      if !items.isEmpty {
        let item = items[selected]
        if !item.explain.isEmpty {
          print("\nExplain:")
          for line in item.explain { print(line) }
        }
      }
      if confirming {
        print("confirm: This action modifies studio state. Proceed?  (y)es / (n)o")
      } else if let tl = toastLine {
        print(tl)
      }
    }
  }

  func allItemsCount(anchorsPack: String, wubBin: String, showPreflight: Bool) -> Int {
    return buildMenu(wubBin: wubBin, anchorsPack: anchorsPack, showPreflight: showPreflight).count
  }

  func firstFailDetailLine(snapshot: StudioStateSnapshot) -> String? {
    guard let fail = snapshot.gates.first(where: { $0.status == .fail }),
          let detail = fail.detail else { return nil }
    return "detail: \(fail.key) \(detail)"
  }

  func truncateMiddle(_ s: String, maxLen: Int) -> String {
    if s.count <= maxLen { return s }
    if maxLen <= 1 { return "…" }
    let head = (maxLen - 1) / 2
    let tail = maxLen - 1 - head
    let start = s.prefix(head)
    let end = s.suffix(tail)
    return String(start) + "…" + String(end)
  }

  func truncateTail(_ s: String, maxLen: Int) -> String {
    if s.count <= maxLen { return s }
    if maxLen <= 1 { return "…" }
    return "…" + s.suffix(maxLen - 1)
  }

  func normalizePath(_ path: String, repoRoot: String) -> String {
    if path.hasPrefix(repoRoot + "/") {
      return "." + path.dropFirst(repoRoot.count)
    }
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path.hasPrefix(home + "/") {
      return "~" + path.dropFirst(home.count)
    }
    return path
  }

  func truncatePath(_ path: String, maxLen: Int, repoRoot: String) -> String {
    let norm = normalizePath(path, repoRoot: repoRoot)
    if norm.count <= maxLen { return norm }
    let parts = norm.split(separator: "/")
    if parts.count >= 2 {
      let head = norm.hasPrefix("~/") ? "~/" : (norm.hasPrefix("./") ? "./" : "/")
      let tail = parts.suffix(2).joined(separator: "/")
      let candidate = head + "…/" + tail
      if candidate.count <= maxLen { return candidate }
    }
    return truncateTail(norm, maxLen: maxLen)
  }

  func renderStationLine(snapshot: StudioStateSnapshot, width: Int) -> String {
    let base = StationBarRender.renderLine(label: "STATION", gates: snapshot.gates, next: snapshot.recommended.command?.joined(separator: " "))
    return base.count <= width ? base : truncateTail(base, maxLen: width)
  }

  func stationSummaryAsync(wubBin: String, timeoutMs: Int, completion: @escaping (String) -> Void) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: wubBin)
    p.arguments = ["station", "status", "--format", "json", "--no-write-report"]
    let out = Pipe()
    p.standardOutput = out
    do { try p.run() } catch {
      completion("unk.")
      return
    }

    let timer = DispatchSource.makeTimerSource()
    timer.schedule(deadline: .now() + .milliseconds(timeoutMs))
    timer.setEventHandler {
      if p.isRunning { p.terminate() }
    }
    timer.resume()

    p.terminationHandler = { _ in
      timer.cancel()
      let od = out.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: od, encoding: .utf8) ?? ""
      guard !output.isEmpty, let data = output.data(using: .utf8) else {
        DispatchQueue.main.async { completion("unk.") }
        return
      }
      struct Envelope: Decodable { let stationState: String?; enum CodingKeys: String, CodingKey { case stationState = "station_state" } }
      let env = try? JSONDecoder().decode(Envelope.self, from: data)
      let state = env?.stationState ?? "unknown"
      switch state {
      case "detected": DispatchQueue.main.async { completion("det.") }
      case "blocked": DispatchQueue.main.async { completion("blk") }
      case "offline": DispatchQueue.main.async { completion("off") }
      default: DispatchQueue.main.async { completion("unk.") }
      }
    }
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

  func resolveWubBinary(repoRoot: String) -> String? {
    let p1 = URL(fileURLWithPath: repoRoot).appendingPathComponent("kernel/cli/.build/release/wub").path
    return FileManager.default.isExecutableFile(atPath: p1) ? p1 : nil
  }

  func runProcess(_ args: [String]) async throws -> Int32 {
    try await OperatorShellService.runProcess(args)
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
