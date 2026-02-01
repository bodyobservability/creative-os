import Foundation
import ArgumentParser

struct Report: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "report",
    abstract: "Generate and view human-readable run reports (v8.7).",
    subcommands: [Generate.self, Open.self]
  )

  struct Generate: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "generate",
      abstract: "Generate a Markdown report for a given run directory."
    )

    @Option(name: .long, help: "Run directory (e.g. runs/<run_id>).")
    var runDir: String

    @Option(name: .long, help: "Output report path (default: runs/<run_id>/report.md).")
    var out: String?

    func run() throws {
      let rid = URL(fileURLWithPath: runDir).lastPathComponent
      let ts = ISO8601DateFormatter().string(from: Date())

      // Discover common receipts
      var sections: [[String:String]] = []

      func addSection(_ heading: String, _ content: String) {
        sections.append(["heading": heading, "content": content])
      }

      let fm = FileManager.default
      let files = (try? fm.contentsOfDirectory(atPath: runDir)) ?? []

      if files.contains("station_receipt.v1.json") {
        addSection("Station Certification", summarizeJSON(path: "\(runDir)/station_receipt.v1.json"))
      }
      if files.contains("release_cut_receipt.v1.json") {
        addSection("Release Cut", summarizeJSON(path: "\(runDir)/release_cut_receipt.v1.json"))
      }
      if files.contains("sonic_sweep_receipt.v1.json") {
        addSection("Sonic Sweep", summarizeJSON(path: "\(runDir)/sonic_sweep_receipt.v1.json"))
      }
      if files.contains("sonic_diff_receipt.v1.json") {
        addSection("Regression Check", summarizeJSON(path: "\(runDir)/sonic_diff_receipt.v1.json"))
      }
      if files.contains("sub_mono_safety_receipt.v1.json") {
        addSection("Sub Mono Safety", summarizeJSON(path: "\(runDir)/sub_mono_safety_receipt.v1.json"))
      }
      if files.contains("transient_lowband_receipt.v1.json") {
        addSection("Transient / Low-band", summarizeJSON(path: "\(runDir)/transient_lowband_receipt.v1.json"))
      }

      let status = inferStatus(from: sections)
      let report = [
        "schema_version": 1,
        "run_id": rid,
        "timestamp": ts,
        "title": "Studio Run Report",
        "status": status,
        "summary": "Automated summary for run \(rid). See sections below for details.",
        "sections": sections
      ] as [String:Any]

      let outPath = out ?? "\(runDir)/report.md"
      let md = renderMarkdown(report: report)
      try md.write(toFile: outPath, atomically: true, encoding: .utf8)
      print("report: \(outPath)")
    }

    private func summarizeJSON(path: String) -> String {
      guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String:Any] else {
        return "_Unable to parse receipt_"
      }
      let status = obj["status"] as? String ?? "unknown"
      let reasons = (obj["reasons"] as? [String])?.joined(separator: "; ") ?? ""
      return "**Status:** \(status)\n\n**Notes:** \(reasons)"
    }

    private func inferStatus(from sections: [[String:String]]) -> String {
      for s in sections {
        if s["content"]?.contains("fail") == true { return "fail" }
      }
      for s in sections {
        if s["content"]?.contains("warn") == true { return "warn" }
      }
      return "pass"
    }

    private func renderMarkdown(report: [String:Any]) -> String {
      var out = ""
      out += "# \(report["title"] as? String ?? "Report")\n\n"
      out += "**Run ID:** \(report["run_id"]!)\n"
      out += "**Timestamp:** \(report["timestamp"]!)\n"
      out += "**Status:** \(report["status"]!)\n\n---\n\n"
      out += "## Summary\n\(report["summary"]!)\n\n---\n\n"
      let sections = report["sections"] as? [[String:String]] ?? []
      for s in sections {
        out += "## \(s["heading"]!)\n\(s["content"]!)\n\n---\n\n"
      }
      return out
    }
  }

  struct Open: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "open",
      abstract: "Open a run report in the default viewer."
    )

    @Option(name: .long, help: "Run directory (e.g. runs/<run_id>).")
    var runDir: String

    func run() throws {
      let path = "\(runDir)/report.md"
      if !FileManager.default.fileExists(atPath: path) {
        throw ValidationError("report.md not found. Run `wub report generate` first.")
      }
      let p = Process()
      p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
      p.arguments = [path]
      try p.run()
    }
  }
}
