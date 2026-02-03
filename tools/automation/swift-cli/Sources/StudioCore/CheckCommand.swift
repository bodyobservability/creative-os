import ArgumentParser
import Foundation

struct WubCheck: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "check")

  @Option(name: .long, help: "Runs directory (default: runs).")
  var runsDir: String = "runs"

  @Option(name: .long, help: "Anchors pack override (default: from local config).")
  var anchorsPack: String? = nil

  func run() async throws {
    let repoRoot = FileManager.default.currentDirectoryPath
    let cfg = try? LocalConfig.loadOrCreate(atRepoRoot: repoRoot)
    let anchors = anchorsPack ?? cfg?.anchorsPack

    let snapshot = StudioStateEvaluator.evaluate(config: .init(
      repoRoot: repoRoot,
      runsDir: runsDir,
      anchorsPack: anchors,
      now: Date(),
      sweepStaleSeconds: 60 * 10,
      readyStaleSeconds: 60 * 10
    ))

    print(StationBarRender.renderLine(label: "STATION", gates: snapshot.gates, next: snapshot.recommended.command?.joined(separator: " ")))

    if let ap = snapshot.anchorsPack {
      print("Anchors: \(ap)")
    } else {
      print("Anchors: NOT SET")
    }

    if !snapshot.blockers.isEmpty {
      print("\nBlockers:")
      for b in snapshot.blockers { print("- \(b)") }
    }
    if !snapshot.warnings.isEmpty {
      print("\nWarnings:")
      for w in snapshot.warnings { print("- \(w)") }
    }

    print("\nNext: \(snapshot.recommended.summary)")

    if !snapshot.blockers.isEmpty {
      throw ExitCode(2)
    }
  }
}
