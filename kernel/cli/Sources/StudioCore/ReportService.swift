import Foundation
import ArgumentParser

struct ReportService {
  struct GenerateConfig {
    let runDir: String
    let out: String?
  }

  static func generate(config: GenerateConfig) throws -> String {
    let rid = URL(fileURLWithPath: config.runDir).lastPathComponent
    let ts = ISO8601DateFormatter().string(from: Date())

    var sections: [[String: String]] = []
    func addSection(_ heading: String, _ content: String) {
      sections.append(["heading": heading, "content": content])
    }

    let fm = FileManager.default
    let files = (try? fm.contentsOfDirectory(atPath: config.runDir)) ?? []

    if files.contains("station_receipt.v1.json") {
      addSection("Station Certification", summarizeJSON(path: "\(config.runDir)/station_receipt.v1.json"))
    }
    if files.contains("release_cut_receipt.v1.json") {
      addSection("Release Cut", summarizeJSON(path: "\(config.runDir)/release_cut_receipt.v1.json"))
    }
    if files.contains("sonic_sweep_receipt.v1.json") {
      addSection("Sonic Sweep", summarizeJSON(path: "\(config.runDir)/sonic_sweep_receipt.v1.json"))
    }
    if files.contains("sonic_diff_receipt.v1.json") {
      addSection("Regression Check", summarizeJSON(path: "\(config.runDir)/sonic_diff_receipt.v1.json"))
    }
    if files.contains("sub_mono_safety_receipt.v1.json") {
      addSection("Sub Mono Safety", summarizeJSON(path: "\(config.runDir)/sub_mono_safety_receipt.v1.json"))
    }
    if files.contains("transient_lowband_receipt.v1.json") {
      addSection("Transient / Low-band", summarizeJSON(path: "\(config.runDir)/transient_lowband_receipt.v1.json"))
    }

    let status = inferStatus(from: sections)
    let report: [String: Any] = [
      "schema_version": 1,
      "run_id": rid,
      "timestamp": ts,
      "title": "Studio Run Report",
      "status": status,
      "summary": "Automated summary for run \(rid). See sections below for details.",
      "sections": sections
    ]

    let outPath = config.out ?? "\(config.runDir)/report.md"
    let md = renderMarkdown(report: report)
    try md.write(toFile: outPath, atomically: true, encoding: .utf8)

    return outPath
  }

  struct OpenConfig {
    let runDir: String
  }

  static func open(config: OpenConfig) throws {
    let path = "\(config.runDir)/report.md"
    if !FileManager.default.fileExists(atPath: path) {
      throw ValidationError("report.md not found. Run `wub report generate` first.")
    }
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    p.arguments = [path]
    try p.run()
  }

  private static func summarizeJSON(path: String) -> String {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return "_Unable to parse receipt_"
    }
    let status = obj["status"] as? String ?? "unknown"
    let reasons = (obj["reasons"] as? [String])?.joined(separator: "; ") ?? ""
    return "**Status:** \(status)\n\n**Notes:** \(reasons)"
  }

  private static func inferStatus(from sections: [[String: String]]) -> String {
    for s in sections {
      if s["content"]?.contains("fail") == true { return "fail" }
    }
    for s in sections {
      if s["content"]?.contains("warn") == true { return "warn" }
    }
    return "pass"
  }

  private static func renderMarkdown(report: [String: Any]) -> String {
    var out = ""
    out += "# \(report["title"] as? String ?? "Report")\n\n"
    out += "**Run ID:** \(report["run_id"]!)\n"
    out += "**Timestamp:** \(report["timestamp"]!)\n"
    out += "**Status:** \(report["status"]!)\n\n---\n\n"
    out += "## Summary\n\(report["summary"]!)\n\n---\n\n"
    let sections = report["sections"] as? [[String: String]] ?? []
    for s in sections {
      out += "## \(s["heading"]!)\n\(s["content"]!)\n\n---\n\n"
    }
    return out
  }
}
