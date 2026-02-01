import Foundation
import ArgumentParser

struct Index: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "index",
    abstract: "Build and inspect artifact/receipt indexes (v1.8).",
    subcommands: [Build.self, Status.self]
  )

  struct Build: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "build",
      abstract: "Build artifact_index.v1.json and receipt_index.v1.json."
    )

    @Option(name: .long, help: "Repo version string to embed in the index (default: v1.8.4).")
    var repoVersion: String = "v1.8.4"

    @Option(name: .long, help: "Output directory for indexes (default: checksums/index).")
    var outDir: String = "checksums/index"

    @Option(name: .long, help: "Runs directory to scan for receipts (default: runs).")
    var runsDir: String = "runs"

    func run() throws {
      try IndexIO.ensureDir(outDir)

      let receiptIndex = ReceiptIndexBuilder.build(runsDir: runsDir)
      let expected = try ExpectedArtifactsParser.parseAll()
      let artifactIndex = ArtifactIndexBuilder.build(repoVersion: repoVersion, expected: expected, receiptIndex: receiptIndex)

      let receiptPath = URL(fileURLWithPath: outDir).appendingPathComponent("receipt_index.v1.json")
      let artifactPath = URL(fileURLWithPath: outDir).appendingPathComponent("artifact_index.v1.json")

      try JSONIO.save(receiptIndex, to: receiptPath)
      try JSONIO.save(artifactIndex, to: artifactPath)

      print("Wrote: \(receiptPath.path)")
      print("Wrote: \(artifactPath.path)")
    }
  }

  struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "status",
      abstract: "Summarize the current artifact_index.v1.json."
    )

    @Option(name: .long, help: "Artifact index path (default: checksums/index/artifact_index.v1.json).")
    var path: String = "checksums/index/artifact_index.v1.json"

    func run() throws {
      let idx = try JSONIO.load(ArtifactIndexV1.self, from: URL(fileURLWithPath: path))
      var counts: [String: Int] = [:]
      for a in idx.artifacts {
        counts[a.status.state, default: 0] += 1
      }
      print("ArtifactIndex v1: \(idx.artifacts.count) artifacts")
      for k in ["current","placeholder","missing","stale","unknown"] {
        if let c = counts[k] { print("  \(k): \(c)") }
      }
    }
  }
}
