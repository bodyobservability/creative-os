import Foundation

struct StudioStateEvaluator {
  struct Config {
    let repoRoot: String
    let runsDir: String
    let anchorsPack: String?
    let now: Date
    let sweepStaleSeconds: TimeInterval
    let readyStaleSeconds: TimeInterval
  }

  static func evaluate(config: Config) -> StudioStateSnapshot {
    let locator = RunLocator(runsDir: config.runsDir)
    let lastRun = locator.latestRunDir()
    let failures = locator.latestFailuresDir(inRunDir: lastRun)
    let readyPath = locator.latestReadyReportPath(inRunDir: lastRun)

    let anchors = config.anchorsPack
    let anchorsValid = anchors != nil && !(anchors?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) && !(anchors?.contains("<pack_id>") ?? false)

    let indexPath = "checksums/index/artifact_index.v1.json"
    let indexExists = FileManager.default.fileExists(atPath: indexPath)
    let counts = ArtifactIndexParser.parseCounts(path: indexPath)
    let missing = counts?.missing ?? 0
    let placeholder = counts?.placeholder ?? 0
    let pendingArtifacts = missing + placeholder

    let sweepSignal = lastRun.flatMap { readLatestSignal(inRunDir: $0, prefix: "sweep_report") }
    let readySignal = readyPath.flatMap { ReceiptSignalReader.readStatus(path: $0) }

    let sweepStale = ReceiptSignalReader.isStale(sweepSignal, maxAgeSeconds: config.sweepStaleSeconds)
    let readyStale = ReceiptSignalReader.isStale(readySignal, maxAgeSeconds: config.readyStaleSeconds)

    var gates: [ReadinessGate] = []
    var blockers: [String] = []
    var warnings: [String] = []

    // A: Anchors
    if anchorsValid {
      gates.append(ReadinessGate(key: "A", label: "Anchors", status: .pass, detail: nil, nextAction: nil))
    } else {
      gates.append(ReadinessGate(key: "A", label: "Anchors", status: .fail, detail: "not set", nextAction: "wub anchors select"))
      blockers.append("Anchors pack not configured")
    }

    // S: Sweep
    if let sig = sweepSignal {
      if sig.status == "pass" {
        if sweepStale {
          gates.append(ReadinessGate(key: "S", label: "Sweep", status: .warn, detail: "stale", nextAction: "wub sweep --modal-test detect"))
          warnings.append("Sweep is stale")
        } else {
          gates.append(ReadinessGate(key: "S", label: "Sweep", status: .pass, detail: nil, nextAction: nil))
        }
      } else {
        gates.append(ReadinessGate(key: "S", label: "Sweep", status: .fail, detail: sig.status, nextAction: "wub sweep --modal-test detect"))
        blockers.append("Sweep failed")
      }
    } else {
      gates.append(ReadinessGate(key: "S", label: "Sweep", status: .pending, detail: "not run", nextAction: "wub sweep --modal-test detect"))
    }

    // I: Index
    if indexExists {
      gates.append(ReadinessGate(key: "I", label: "Index", status: .pass, detail: nil, nextAction: nil))
    } else {
      gates.append(ReadinessGate(key: "I", label: "Index", status: .fail, detail: "missing", nextAction: "wub index build"))
      blockers.append("Index missing")
    }

    // F: Files/Artifacts
    if pendingArtifacts == 0 {
      gates.append(ReadinessGate(key: "F", label: "Files", status: .pass, detail: nil, nextAction: nil))
    } else {
      let detail = "missing=\(missing), placeholder=\(placeholder)"
      gates.append(ReadinessGate(key: "F", label: "Files", status: .fail, detail: detail, nextAction: "wub assets export-all --anchors-pack \(anchors ?? "<pack>") --overwrite"))
      blockers.append("Artifacts missing or placeholder")
    }

    // R: Ready
    if let sig = readySignal {
      if sig.status == "pass" {
        if readyStale {
          gates.append(ReadinessGate(key: "R", label: "Ready", status: .warn, detail: "stale", nextAction: "wub ready --anchors-pack-hint \(anchors ?? "<pack>")"))
          warnings.append("Ready verify is stale")
        } else {
          gates.append(ReadinessGate(key: "R", label: "Ready", status: .pass, detail: nil, nextAction: nil))
        }
      } else {
        gates.append(ReadinessGate(key: "R", label: "Ready", status: .fail, detail: sig.status, nextAction: "wub ready --anchors-pack-hint \(anchors ?? "<pack>")"))
        blockers.append("Ready verify failed")
      }
    } else {
      gates.append(ReadinessGate(key: "R", label: "Ready", status: .pending, detail: "not run", nextAction: "wub ready --anchors-pack-hint \(anchors ?? "<pack>")"))
    }

    let recommended = recommendNext(gates: gates, anchors: anchors)

    return StudioStateSnapshot(
      gates: gates,
      blockers: blockers,
      warnings: warnings,
      recommended: recommended,
      anchorsPack: anchors,
      lastRunDir: lastRun,
      lastFailuresDir: failures,
      lastReadyReport: readyPath,
      pendingArtifacts: missing + placeholder,
      placeholderArtifacts: placeholder
    )
  }

  private static func recommendNext(gates: [ReadinessGate], anchors: String?) -> RecommendedNext {
    if let g = gates.first(where: { $0.status == .fail }), let next = g.nextAction {
      return RecommendedNext(summary: "\(g.label) → \(next)", command: next.split(separator: " ").map(String.init), danger: isDangerous(next))
    }
    if let g = gates.first(where: { $0.status == .pending }), let next = g.nextAction {
      return RecommendedNext(summary: "\(g.label) pending → \(next)", command: next.split(separator: " ").map(String.init), danger: isDangerous(next))
    }
    if let g = gates.first(where: { $0.status == .warn }), let next = g.nextAction {
      return RecommendedNext(summary: "\(g.label) stale → \(next)", command: next.split(separator: " ").map(String.init), danger: isDangerous(next))
    }
    return RecommendedNext(summary: "CLEARED", command: nil, danger: false)
  }

  private static func isDangerous(_ cmd: String) -> Bool {
    return cmd.contains("export") || cmd.contains("drift fix") || cmd.contains("repair") || cmd.contains("certify")
  }

  private static func readLatestSignal(inRunDir dir: String, prefix: String) -> ReceiptSignal? {
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return nil }
    let candidates = files.filter { $0.hasPrefix(prefix) && $0.hasSuffix(".json") }.sorted()
    guard let chosen = candidates.last else { return nil }
    return ReceiptSignalReader.readStatus(path: URL(fileURLWithPath: dir).appendingPathComponent(chosen).path)
  }
}
