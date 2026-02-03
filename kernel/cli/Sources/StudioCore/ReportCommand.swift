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
      let outPath = try ReportService.generate(config: .init(runDir: runDir, out: out))
      print("report: \(outPath)")
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
      try ReportService.open(config: .init(runDir: runDir))
    }
  }
}
