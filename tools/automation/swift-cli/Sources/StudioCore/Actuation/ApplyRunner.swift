import Foundation
import CoreGraphics

final class ApplyRunner {
  struct EvidenceOptions {
    var writeOnSuccess: Bool = false
    var writeOnFailure: Bool = true
    var maxOcrLines: Int = 250
    static let `default` = EvidenceOptions()
  }

  let capture: FrameCapture
  let regions: RegionsV1
  let actuator: Actuator

  var traceWriter: TraceWriter?
  var receiptWriter: ReceiptWriter?
  var evidenceOptions: EvidenceOptions = .default
  var runDir: URL?
  var anchorsPackPath: String?
  var watchdogOpMs: Int = 30000
  private var midiSendCache: [String: MidiSend] = [:]

  init(capture: FrameCapture, regions: RegionsV1, actuator: Actuator) {
    self.capture = capture
    self.regions = regions
    self.actuator = actuator
  }

  func run(plan: PlanV1, runDir: URL) async throws -> ResolveReport {
    self.runDir = runDir
    var prompts: [Prompt] = []
    var results: [ResolveResult] = []

    try await capture.start()
    defer { Task { await capture.stop() } }

    for op in plan.ops {
      let ok = try await runOp(op)
      results.append(ResolveResult(requestId: op.id, decision: ok ? "ok" : "failed"))
      if !ok {
        prompts.append(Prompt(type: "apply_failed", title: "Apply failed", message: "Op \(op.id) failed. See failures.", relatedRequestId: op.id))
        break
      }
    }

    return ResolveReport(schemaVersion: 1,
                        generatedAt: ISO8601DateFormatter().string(from: Date()),
                        environment: ["os":"macos"],
                        results: results,
                        prompts: prompts,
                        meta: nil)
  }

  private func runOp(_ op: PlanOp) async throws -> Bool {
    let retries = op.retries ?? 2
    let opStart = Date()
    traceWriter?.beginOp(op.id)

    for attempt in 0...retries {
      traceWriter?.beginAttempt(opId: op.id, attemptIndex: attempt)
      traceWriter?.event(opId: op.id, attemptIndex: attempt, kind: "attempt", name: "start")

      do {
        if elapsedMs(since: opStart) > watchdogOpMs {
          try await abortForWatchdog(opId: op.id, attempt: attempt)
          return false
        }

        try await ensureNoModalOrDismiss(opId: op.id, attempt: attempt)

        if let pre = op.pre, !(try await assertsPass(pre, opId: op.id, attempt: attempt)) {
          try doRecovery(op, opId: op.id, attempt: attempt)
          continue
        }

        try await perform(op.action, opId: op.id, attempt: attempt)
        try await ensureNoModalOrDismiss(opId: op.id, attempt: attempt)

        if let post = op.post, !(try await assertsPass(post, opId: op.id, attempt: attempt)) {
          try saveFailure(opId: op.id, note: "post_failed_attempt_\(attempt)")
          try doRecovery(op, opId: op.id, attempt: attempt)
          continue
        }

        traceWriter?.endAttempt(opId: op.id, attemptIndex: attempt, result: "ok")
        let ms = Int(Date().timeIntervalSince(opStart) * 1000)
        receiptWriter?.recordOp(opId: op.id, attempts: attempt + 1, result: "ok", durationMs: ms, notes: op.notes)
        receiptWriter?.flush(); traceWriter?.flush()
        return true

      } catch {
        traceWriter?.event(opId: op.id, attemptIndex: attempt, kind: "error", name: "exception", details: ["msg": error.localizedDescription])
        traceWriter?.endAttempt(opId: op.id, attemptIndex: attempt, result: "retry")
        traceWriter?.flush()

        if attempt == retries {
          let ms = Int(Date().timeIntervalSince(opStart) * 1000)
          receiptWriter?.recordOp(opId: op.id, attempts: attempt + 1, result: "failed", durationMs: ms, notes: op.notes)
          receiptWriter?.recordFailure(opId: op.id, attempts: attempt + 1, reason: error.localizedDescription, artifactsDir: "failures/\(op.id)")
          receiptWriter?.flush()
          try saveFailure(opId: op.id, note: "exhausted: \(error.localizedDescription)")
          return false
        }
      }
    }

    return false
  }

  private func elapsedMs(since start: Date) -> Int { Int(Date().timeIntervalSince(start) * 1000.0) }

  private func abortForWatchdog(opId: String, attempt: Int) async throws {
    traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "error", name: "watchdog_timeout", details: ["watchdog_ms": "\(watchdogOpMs)"])
    try saveFailure(opId: opId, note: "Watchdog timeout exceeded (\(watchdogOpMs) ms)")
    throw NSError(domain: "ApplyRunner", code: 98, userInfo: [NSLocalizedDescriptionKey: "Watchdog timeout exceeded"])
  }

  private func ensureNoModalOrDismiss(opId: String, attempt: Int) async throws {
    guard let rect = regions.cgRectTopLeft("os.file_dialog") else { return }
    let frame = try await capture.latestFrame(timeoutMs: 1500)
    let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
    let lines = try VisionOCR.recognizeLines(cgImage: crop)
    if ModalCancel.modalPresent(lines: lines) {
      let ok = await ModalCancel.dismiss(capture: capture, regions: regions, actuator: actuator, anchorsPackPath: anchorsPackPath, opId: opId, attempt: attempt, trace: traceWriter)
      if !ok {
        try saveFailure(opId: opId, note: "Modal dialog present and could not be dismissed.")
        throw NSError(domain: "ApplyRunner", code: 91, userInfo: [NSLocalizedDescriptionKey: "Modal dialog present and could not be dismissed"])
      }
    }
  }

  private func doRecovery(_ op: PlanOp, opId: String, attempt: Int) throws {
    traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "recovery", name: "global_escape")
    try? actuator.keyChord("ESC")
    try? actuator.keyChord("ESC")
    if let rec = op.recover {
      for a in rec { try? performSync(a, opId: opId, attempt: attempt) }
    }
  }

  private func performSync(_ action: PlanAction, opId: String, attempt: Int) throws {
    switch action.type {
    case "press_keys":
      for k in action.keys ?? [] { try actuator.keyChord(k) }
    case "sleep":
      try actuator.sleepMs(action.ms ?? 100)
    default:
      _ = opId; _ = attempt
      break
    }
  }

  private func perform(_ action: PlanAction, opId: String, attempt: Int) async throws {
    switch action.type {
    case "sleep":
      try actuator.sleepMs(action.ms ?? 100)

    case "press_keys":
      for k in action.keys ?? [] { try actuator.keyChord(k) }

    case "type_text":
      try actuator.typeText(action.text ?? "")

    case "search_browser":
      try await clickRegionCenter(regionId: action.fallbackRegion ?? "browser.search")
      traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "action", name: "search_browser", details: ["query": action.query ?? ""])
      try actuator.keyChord("CMD+A")
      try actuator.typeText(action.query ?? "")
      try actuator.sleepMs(180)

    case "click_ocr_match":
      try await clickOCR(regionId: action.region!, match: action.match!, double: false, opId: opId, attempt: attempt)

    case "dblclick_ocr_match":
      try await clickOCR(regionId: action.region!, match: action.match!, double: true, opId: opId, attempt: attempt)

    case "open_plugin_window":
      let pn = action.pluginName ?? "Serum"
      let dc = action.deviceChainText ?? pn
      try await performOpenPluginWindow(pluginName: pn, deviceChainText: dc, opId: opId, attempt: attempt)

    case "click_anchor":
      if let anchor = action.anchorId {
        try await performClickAnchor(anchorId: anchor, fallbackRegion: action.fallbackRegion, opId: opId, attempt: attempt)
      }

    case "send_midi_cc":
      let dest = action.midiDest ?? "WUB_VOICE"
      let ch = action.channel ?? 1
      guard let cc = action.cc, let value = action.value else {
        throw NSError(domain: "ApplyRunner", code: 200, userInfo: [NSLocalizedDescriptionKey: "send_midi_cc missing cc/value"])
      }
      let sender = try midiSender(destContains: dest)
      try sender.sendCC(cc: cc, value: value, channel: ch)

    case "send_midi_note":
      let dest = action.midiDest ?? "WUB_VOICE"
      let ch = action.channel ?? 1
      guard let note = action.note else {
        throw NSError(domain: "ApplyRunner", code: 201, userInfo: [NSLocalizedDescriptionKey: "send_midi_note missing note"])
      }
      let vel = action.velocity ?? 127
      let sender = try midiSender(destContains: dest)
      try sender.sendNoteOn(note: note, velocity: vel, channel: ch)

    default:
      break
    }
  }

  private func assertsPass(_ asserts: [PlanAssert], opId: String, attempt: Int) async throws -> Bool {
    for a in asserts {
      switch a.type {
      case "ui_text_contains":
        guard let regionId = a.region, let text = a.text else { return false }
        let minConf = a.minConf ?? 0.7
        if !(try await regionContainsText(regionId: regionId, text: text, minConf: minConf, opId: opId, attempt: attempt)) { return false }

      case "ui_text_contains_any":
        guard let regionId = a.region, let tokens = a.tokens, !tokens.isEmpty else { return false }
        let minConf = a.minConf ?? 0.65
        if !(try await regionContainsAnyToken(regionId: regionId, tokens: tokens, minConf: minConf, opId: opId, attempt: attempt)) { return false }

      case "ui_anchor_present":
        if let anchor = a.anchorId {
          if !(try await assertUiAnchorPresent(anchorId: anchor, minScore: a.minScore, opId: opId, attempt: attempt)) { return false }
        } else { return false }

      case "plugin_window_open":
        if let pn = a.pluginName {
          if !(try await assertPluginWindowOpen(pluginName: pn, opId: opId, attempt: attempt)) { return false }
        } else { return false }

      case "no_modal_dialog":
        if regions.cgRectTopLeft("os.file_dialog") != nil {
          let bad = try await regionContainsAny(regionId: "os.file_dialog", keywords: ModalCancel.modalKeywords, minConf: 0.55)
          if bad { return false }
        }

      default:
        continue
      }
    }
    return true
  }

  func clickRegionCenter(regionId: String) async throws {
    guard let rect = regions.cgRectTopLeft(regionId) else { throw NSError(domain: "ApplyRunner", code: 20, userInfo: [NSLocalizedDescriptionKey: "Unknown region: \(regionId)"]) }
    let center = CGPoint(x: rect.midX, y: rect.midY)
    try actuator.home()
    try actuator.moveTo(screenPointTopLeft: center)
    try actuator.click()
    try actuator.sleepMs(80)
  }

  func clickOCR(regionId: String, match: OCRMatchSpec, double: Bool, opId: String, attempt: Int) async throws {
    guard let rect = regions.cgRectTopLeft(regionId) else { throw NSError(domain: "ApplyRunner", code: 10, userInfo: [NSLocalizedDescriptionKey: "Unknown region \(regionId)"]) }
    let full = try await capture.latestFrame()
    let crop = ScreenMapper.cropTopLeft(img: full, rectTopLeft: rect)
    let lines = try VisionOCR.recognizeLines(cgImage: crop)

    let chosen = OCRMatcher.bestMatch(lines: lines, target: match.text, mode: match.mode, minConf: match.minConf ?? 0.7)
    traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "action", name: double ? "dblclick_ocr_match" : "click_ocr_match",
                       details: ["region": regionId, "target": match.text, "chosen": chosen?.line.text ?? "nil"])

    if evidenceOptions.writeOnSuccess, let runDir = runDir {
      try? dumpEvidence(opId: opId, runDir: runDir, full: full, rect: rect, crop: crop, lines: lines, match: match, chosen: chosen, folder: "evidence")
    }

    guard let chosen = chosen else {
      if evidenceOptions.writeOnFailure, let runDir = runDir {
        try? dumpEvidence(opId: opId, runDir: runDir, full: full, rect: rect, crop: crop, lines: lines, match: match, chosen: nil, folder: "failures")
      }
      throw NSError(domain: "ApplyRunner", code: 11, userInfo: [NSLocalizedDescriptionKey: "No OCR match for \(match.text) in \(regionId)"])
    }

    let center = CGPoint(x: chosen.line.bbox.midX, y: chosen.line.bbox.midY + 2)
    let screenPt = ScreenMapper.regionPointToScreen(regionRectTopLeft: rect, pointInRegion: center)
    try actuator.home()
    try actuator.moveTo(screenPointTopLeft: screenPt)
    if double { try actuator.dblclick() } else { try actuator.click() }
    try actuator.sleepMs(120)
  }

  func regionContainsText(regionId: String, text: String, minConf: Double, opId: String, attempt: Int) async throws -> Bool {
    guard let rect = regions.cgRectTopLeft(regionId) else { return false }
    let frame = try await capture.latestFrame(timeoutMs: 1500)
    let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
    let lines = try VisionOCR.recognizeLines(cgImage: crop)
    let found = OCRMatcher.bestMatch(lines: lines, target: text, mode: "contains", minConf: minConf) != nil
    traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "assert", name: "ui_text_contains", details: ["region": regionId, "text": text, "result": found ? "true" : "false"])
    return found
  }

  private func regionContainsAny(regionId: String, keywords: [String], minConf: Double) async throws -> Bool {
    guard let rect = regions.cgRectTopLeft(regionId) else { return false }
    let frame = try await capture.latestFrame(timeoutMs: 1500)
    let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
    let lines = try VisionOCR.recognizeLines(cgImage: crop).filter { $0.confidence >= minConf }
    return ModalCancel.modalPresent(lines: lines)
  }

  private func regionContainsAnyToken(regionId: String, tokens: [String], minConf: Double, opId: String, attempt: Int) async throws -> Bool {
    guard let rect = regions.cgRectTopLeft(regionId) else { return false }
    let frame = try await capture.latestFrame(timeoutMs: 1500)
    let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
    let lines = try VisionOCR.recognizeLines(cgImage: crop)
    for t in tokens {
      if OCRMatcher.bestMatch(lines: lines, target: t, mode: "contains", minConf: minConf) != nil {
        traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "assert", name: "ui_text_contains_any",
                           details: ["region": regionId, "tokens": tokens.joined(separator: "|"), "result": "true"])
        return true
      }
    }
    traceWriter?.event(opId: opId, attemptIndex: attempt, kind: "assert", name: "ui_text_contains_any",
                       details: ["region": regionId, "tokens": tokens.joined(separator: "|"), "result": "false"])
    return false
  }

  private func dumpEvidence(opId: String, runDir: URL, full: CGImage, rect: CGRect, crop: CGImage, lines: [OCRLine],
                            match: OCRMatchSpec, chosen: OCRMatcher.Match?, folder: String) throws {
    let dir = runDir.appendingPathComponent("\(folder)/\(opId)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

    try ImageDump.savePNG(full, to: dir.appendingPathComponent("frame_full.png"))
    try ImageDump.savePNG(crop, to: dir.appendingPathComponent("region_\(regionSan(match.text)).png"))

    let dump = OCRDump(regionId: "region", target: match.text, matchMode: match.mode, minConf: match.minConf,
                       lines: lines.prefix(evidenceOptions.maxOcrLines).map(OCRDumpLine.init))
    try JSONIO.save(dump, to: dir.appendingPathComponent("ocr.json"))

    if let chosen = chosen {
      let matchObj: [String: Any] = [
        "target": match.text,
        "mode": match.mode,
        "minConf": match.minConf ?? 0.7,
        "chosen": [
          "score": chosen.score,
          "text": chosen.line.text,
          "confidence": chosen.line.confidence,
          "bbox": ["x": chosen.line.bbox.origin.x, "y": chosen.line.bbox.origin.y, "w": chosen.line.bbox.size.width, "h": chosen.line.bbox.size.height]
        ]
      ]
      let data = try JSONSerialization.data(withJSONObject: matchObj, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: dir.appendingPathComponent("match.json"))
    }
  }

  private func regionSan(_ s: String) -> String {
    s.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
  }

  func saveFailure(opId: String, note: String) throws {
    guard let runDir = runDir else { return }
    let dir = runDir.appendingPathComponent("failures/\(opId)", isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try note.data(using: .utf8)?.write(to: dir.appendingPathComponent("note.txt"))
  }

  private func midiSender(destContains: String) throws -> MidiSend {
    if let sender = midiSendCache[destContains] { return sender }
    let sender = try MidiSend(destNameContains: destContains)
    midiSendCache[destContains] = sender
    return sender
  }
}
