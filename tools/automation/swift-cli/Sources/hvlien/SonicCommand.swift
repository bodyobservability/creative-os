import Foundation
import ArgumentParser

struct Sonic: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "sonic",
    abstract: "Sonic probe + calibration + regression + governance (v7–v8).",
    subcommands: [
      // v7 analysis + calibration
      Analyze.self,
      Sweep.self,
      SonicSweepRun.self,
      SonicSweepCompile.self,
      SonicTuneCommand.self,
      SonicCalibrateCommand.self,
      SonicDiffCommand.self,
      ProfilePatchCommand.self,
      SubMonoCommand.self,
      TransientLowbandCommand.self,

      // v8 governance
      SonicCertifyCommand.self,
      Baseline.self
    ]
  )

  struct Analyze: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "analyze",
      abstract: "Analyze a rendered/recorded WAV/AIFF file and emit a sonic receipt."
    )

    @Option(name: .long, help: "Input audio file path (wav/aiff).")
    var input: String

    @Option(name: .long, help: "Thresholds JSON path (optional).")
    var thresholds: String = "specs/sonic/thresholds/bass_music_defaults.v1.json"

    @Option(name: .long, help: "Output receipt path (default: runs/<run_id>/sonic_receipt.v1.json).")
    var out: String?

    @Option(name: .long, help: "Optional rack_id for attribution.")
    var rackId: String?

    @Option(name: .long, help: "Optional profile_id for attribution.")
    var profileId: String?

    func run() throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

      let inputURL = URL(fileURLWithPath: input)
      let (metrics, _, _) = try SonicAnalyze.analyze(url: inputURL)

      var th = SonicAnalyze.Thresholds()
      if !thresholds.isEmpty, FileManager.default.fileExists(atPath: thresholds),
         let data = try? Data(contentsOf: URL(fileURLWithPath: thresholds)),
         let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
         let t = obj["thresholds"] as? [String: Any] {
        if let v = t["max_true_peak_dbfs"] as? Double { th.maxTruePeakDbfs = v }
        if let v = t["max_dc_offset_abs"] as? Double { th.maxDcOffsetAbs = v }
        if let v = t["min_stereo_correlation"] as? Double { th.minStereoCorrelation = v }
        if let v = t["max_rms_dbfs_warn"] as? Double { th.maxRmsDbfsWarn = v }
        if let v = t["max_rms_dbfs_fail"] as? Double { th.maxRmsDbfsFail = v }
      }

      let (status, reasons, thMap) = SonicAnalyze.classify(metrics: metrics, thresholds: th)

      let receipt = SonicReceiptV1(
        schemaVersion: 1,
        runId: runId,
        timestamp: ISO8601DateFormatter().string(from: Date()),
        inputAudio: input,
        status: status,
        profileId: profileId,
        rackId: rackId,
        metrics: metrics,
        thresholds: thMap,
        reasons: reasons
      )

      let outPath = out ?? runDir.appendingPathComponent("sonic_receipt.v1.json").path
      try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))

      print("status: \(status)")
      if !reasons.isEmpty {
        print("reasons:")
        for r in reasons { print(" - \(r)") }
      }
      print("receipt: \(outPath)")
      if status == "fail" { throw ExitCode(1) }
    }
  }

  struct Sweep: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "sweep",
      abstract: "Analyze a directory of audio files rendered at macro positions and emit a sweep receipt."
    )

    @Option(name: .long, help: "Macro name (e.g. Width, Energy).")
    var macro: String

    @Option(name: .long, help: "Directory containing audio files. Filenames should include position like pos0.00, pos0.25, etc.")
    var dir: String

    @Option(name: .long, help: "Thresholds JSON path (optional).")
    var thresholds: String = "specs/sonic/thresholds/bass_music_sweep_defaults.v1.json"

    @Option(name: .long, help: "Output receipt path (default: runs/<run_id>/sonic_sweep_receipt.v1.json).")
    var out: String?

    @Option(name: .long) var rackId: String?
    @Option(name: .long) var profileId: String?

    func run() throws {
      let runId = RunContext.makeRunId()
      let runDir = URL(fileURLWithPath: "runs").appendingPathComponent(runId, isDirectory: true)
      try FileManager.default.createDirectory(at: runDir, withIntermediateDirectories: true)

      let folder = URL(fileURLWithPath: dir, isDirectory: true)
      let files = (try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil))
        .filter { ["wav","aiff","aif"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }

      if files.count < 2 {
        throw ValidationError("Need at least 2 audio files in dir.")
      }

      let th = SonicSweep.loadThresholds(path: thresholds.isEmpty ? nil : thresholds)
      var samples: [SonicSweepSampleV1] = []

      for f in files {
        guard let pos = parsePosition(from: f.lastPathComponent) else { continue }
        let (metrics, _, _) = try SonicAnalyze.analyze(url: f)
        let (status, reasons) = SonicSweep.classifySample(metrics: metrics, thresholds: th)
        samples.append(SonicSweepSampleV1(position: pos, inputAudio: f.path, metrics: metrics, status: status, reasons: reasons))
      }

      if samples.count < 2 { throw ValidationError("Could not parse positions from filenames. Include like pos0.25.") }

      let positions = samples.map { $0.position }.sorted()
      let (status, summary, _) = SonicSweep.aggregate(macro: macro, samples: samples, thresholds: th)

      let thMap: [String: Double] = [
        "max_true_peak_dbfs": th.maxTruePeakDbfs,
        "max_dc_offset_abs": th.maxDcOffsetAbs,
        "min_stereo_correlation": th.minStereoCorrelation,
        "max_rms_dbfs_warn": th.maxRmsDbfsWarn,
        "max_rms_dbfs_fail": th.maxRmsDbfsFail
      ]

      let receipt = SonicSweepReceiptV1(
        schemaVersion: 1,
        runId: runId,
        timestamp: ISO8601DateFormatter().string(from: Date()),
        macro: macro,
        profileId: profileId,
        rackId: rackId,
        positions: positions,
        status: status,
        thresholds: thMap,
        summary: summary,
        samples: samples.sorted { $0.position < $1.position }
      )

      let outPath = out ?? runDir.appendingPathComponent("sonic_sweep_receipt.v1.json").path
      try JSONIO.save(receipt, to: URL(fileURLWithPath: outPath))

      print("status: \(status)")
      print("suggested_safe_max_position: \(String(format: "%.2f", summary.suggestedSafeMaxPosition))")
      print("receipt: \(outPath)")
      if status == "fail" { throw ExitCode(1) }
    }

    private func parsePosition(from name: String) -> Double? {
      // expects substring like "pos0.25" or "pos1.00"
      guard let r = name.range(of: "pos") else { return nil }
      let tail = name[r.upperBound...]
      let num = tail.prefix { (ch: Character) in
        ch.isNumber || ch == "." || ch == "-"
      }
      return Double(num)
    }
  }
}
