import Foundation
import ArgumentParser
import CoreGraphics

extension Assets {
  struct ExportPreflight: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "preflight",
      abstract: "Export preflight checks (regions + OCR + anchors) before running exports."
    )

    @OptionGroup var common: CommonOptions

    @Option(name: .long, help: "Anchors pack path (optional).")
    var anchorsPack: String?

    @Flag(name: .long, help: "Write report to \(RepoPaths.defaultRunsDir())/<run_id>/export_preflight_report.v1.json.")
    var writeReport: Bool = true

    func run() async throws {
      let ctx = RunContext(common: common)
      try ctx.ensureRunDir()

      let report = try await ExportPreflightRunner.run(common: common,
                                                       anchorsPack: anchorsPack,
                                                       runId: ctx.runId,
                                                       runDir: ctx.runDir)
      print("EXPORT PREFLIGHT (v1)")
      print("status: \(report.status.uppercased())")
      for c in report.checks {
        print("- \(c.id): \(c.status)")
      }
      if !report.notes.isEmpty {
        print("\nnotes:")
        for n in report.notes { print("  - \(n)") }
      }
      if writeReport {
        print("report: \(RepoPaths.defaultRunsDir())/\(ctx.runId)/export_preflight_report.v1.json")
      }
      if report.status == "fail" { throw ExitCode(2) }
    }
  }
}

enum ExportPreflightRunner {
  static let defaultRequiredRegions: [String] = [
    "tracks.list",
    "device.chain",
    "os.file_dialog",
    "os.file_dialog.filename_field"
  ]

  static let defaultRequiredOcrRegions: [String] = [
    "tracks.list",
    "device.chain"
  ]

  static func run(common: CommonOptions,
                  anchorsPack: String?,
                  runId: String,
                  runDir: URL,
                  requiredRegions: [String] = defaultRequiredRegions,
                  requiredOcrRegions: [String] = defaultRequiredOcrRegions,
                  requireNoModal: Bool = true) async throws -> ExportPreflightReportV1 {
    let regions = try JSONIO.load(RegionsV1.self, from: URL(fileURLWithPath: common.regionsConfig))

    var checks: [ExportPreflightCheckV1] = []
    var notes: [String] = []
    var hasFail = false
    var hasWarn = false

    let missingRegions = requiredRegions.filter { regions.cgRectTopLeft($0) == nil }
    if missingRegions.isEmpty {
      checks.append(.init(id: "regions_present", status: "pass", details: ["required": requiredRegions.joined(separator: ","), "missing": ""]))
    } else {
      checks.append(.init(id: "regions_present", status: "fail", details: ["required": requiredRegions.joined(separator: ","), "missing": missingRegions.joined(separator: ",")]))
      hasFail = true
    }

    let cap = FrameCapture()
    try await cap.start()
    defer { Task { await cap.stop() } }

    let frame: CGImage
    do {
      frame = try await cap.latestFrame(timeoutMs: 2000)
    } catch {
      checks.append(.init(id: "screen_capture", status: "fail", details: ["error": error.localizedDescription]))
      hasFail = true
      return finalize(runId: runId, runDir: runDir, checks: checks, notes: notes, hasFail: hasFail, hasWarn: hasWarn)
    }

    for rid in requiredOcrRegions {
      guard let rect = regions.cgRectTopLeft(rid) else {
        checks.append(.init(id: "ocr_\(rid)", status: "fail", details: ["reason": "missing_region"]))
        hasFail = true
        continue
      }
      let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
      let lines = (try? VisionOCR.recognizeLines(cgImage: crop)) ?? []
      if lines.isEmpty {
        checks.append(.init(id: "ocr_\(rid)", status: "fail", details: ["lines": "0"]))
        hasFail = true
      } else {
        checks.append(.init(id: "ocr_\(rid)", status: "pass", details: ["lines": String(lines.count)]))
      }
    }

    if requireNoModal, let rect = regions.cgRectTopLeft("os.file_dialog") {
      let crop = ScreenMapper.cropTopLeft(img: frame, rectTopLeft: rect)
      let lines = (try? VisionOCR.recognizeLines(cgImage: crop)) ?? []
      if ModalCancel.modalPresent(lines: lines) {
        checks.append(.init(id: "no_modal_dialog", status: "fail", details: ["region": "os.file_dialog"]))
        hasFail = true
      } else {
        checks.append(.init(id: "no_modal_dialog", status: "pass", details: ["region": "os.file_dialog"]))
      }
    }

    if let ap = anchorsPack, !ap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !ap.contains("<pack_id>") {
      let ok = FileManager.default.fileExists(atPath: ap)
      checks.append(.init(id: "anchors_pack_path_exists", status: ok ? "pass" : "warn", details: ["path": ap]))
      if !ok { hasWarn = true; notes.append("Anchors pack path does not exist; automation may be brittle.") }
    } else {
      checks.append(.init(id: "anchors_pack_configured", status: "warn", details: ["path": anchorsPack ?? ""]))
      hasWarn = true
      notes.append("Anchors pack not configured; OCR-only exports are more fragile.")
    }

    return finalize(runId: runId, runDir: runDir, checks: checks, notes: notes, hasFail: hasFail, hasWarn: hasWarn)
  }

  private static func finalize(runId: String,
                               runDir: URL,
                               checks: [ExportPreflightCheckV1],
                               notes: [String],
                               hasFail: Bool,
                               hasWarn: Bool) -> ExportPreflightReportV1 {
    let status = hasFail ? "fail" : (hasWarn ? "warn" : "pass")
    let report = ExportPreflightReportV1(schemaVersion: 1,
                                         runId: runId,
                                         timestamp: ISO8601DateFormatter().string(from: Date()),
                                         status: status,
                                         checks: checks,
                                         notes: notes)
    try? JSONIO.save(report, to: runDir.appendingPathComponent("export_preflight_report.v1.json"))
    return report
  }
}
