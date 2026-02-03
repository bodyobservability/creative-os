import Foundation
import ArgumentParser

struct Index: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "index",
    abstract: "Build and inspect artifact/receipt indexes.",
    subcommands: [Build.self, Status.self]
  )

  struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "build",
      abstract: "Build artifact_index.v1.json and receipt_index.v1.json."
    )

    @Option(name: .long, help: "Repo version string to embed in the index.")
    var repoVersion: String = "current"

    @Option(name: .long, help: "Output directory for indexes (default: \(RepoPaths.defaultChecksumsIndexDir())).")
    var outDir: String = RepoPaths.defaultChecksumsIndexDir()

    @Option(name: .long, help: "Runs directory to scan for receipts (default: \(RepoPaths.defaultRunsDir())).")
    var runsDir: String = RepoPaths.defaultRunsDir()

    func run() throws {
      let result = try IndexService.build(config: .init(repoVersion: repoVersion, outDir: outDir, runsDir: runsDir))
      print("Wrote: \(result.receiptPath)")
      print("Wrote: \(result.artifactPath)")
    }
  }

  struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "status",
      abstract: "Summarize the current artifact_index.v1.json."
    )

    @Option(name: .long, help: "Artifact index path (default: \(RepoPaths.defaultArtifactIndexPath())).")
    var path: String = RepoPaths.defaultArtifactIndexPath()

    func run() throws {
      let result = try IndexService.status(path: path)
      print("ArtifactIndex v1: \(result.total) artifacts")
      for k in ["current","placeholder","missing","stale","unknown"] {
        if let c = result.counts[k] { print("  \(k): \(c)") }
      }
    }
  }
}
