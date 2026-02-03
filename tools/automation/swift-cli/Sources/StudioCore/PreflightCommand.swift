import ArgumentParser
import Foundation

struct WubPreflight: AsyncParsableCommand {
  static let configuration = CommandConfiguration(commandName: "preflight")

  @Option(name: .long, help: "Runs directory (default: runs).")
  var runsDir: String = "runs"

  @Option(name: .long, help: "Anchors pack override (default: from local config).")
  var anchorsPack: String? = nil

  @Flag(name: .long, help: "Run safe prerequisites automatically (index build, sweep).")
  var auto: Bool = false

  @Flag(name: .long, help: "Allow dangerous remediation prompts (export-all, drift fix, repair).")
  var allowDanger: Bool = false

  func run() async throws {
    let repoRoot = FileManager.default.currentDirectoryPath
    let cfg = try? LocalConfig.loadOrCreate(atRepoRoot: repoRoot)
    let anchors = anchorsPack ?? cfg?.anchorsPack
    let hv = resolveWubBinary(repoRoot: repoRoot) ?? "wub"

    var snapshot = StudioStateEvaluator.evaluate(config: .init(
      repoRoot: repoRoot,
      runsDir: runsDir,
      anchorsPack: anchors,
      now: Date(),
      sweepStaleSeconds: 60 * 30,
      readyStaleSeconds: 60 * 30
    ))

    if auto {
      if snapshot.gates.first(where: { $0.key == "I" && $0.status == .fail }) != nil {
        _ = try? await OperatorShellService.runProcess([hv, "index", "build"])
      }
      if snapshot.gates.first(where: { $0.key == "S" && ($0.status == .pending || $0.status == .warn) }) != nil {
        _ = try? await OperatorShellService.runProcess([hv, "sweep", "--modal-test", "detect", "--allow-ocr-fallback"])
      }
      snapshot = StudioStateEvaluator.evaluate(config: .init(
        repoRoot: repoRoot,
        runsDir: runsDir,
        anchorsPack: anchors,
        now: Date(),
        sweepStaleSeconds: 60 * 30,
        readyStaleSeconds: 60 * 30
      ))
    }

    print(StationBarRender.renderLine(label: "STATION", gates: snapshot.gates, next: snapshot.recommended.command?.joined(separator: " ")))

    if !snapshot.blockers.isEmpty {
      print("\nBLOCKED")
      print("\nBlockers:")
      for b in snapshot.blockers { print("- \(b)") }

      if let cmd = snapshot.recommended.command {
        print("\nNext:")
        print("- \(cmd.joined(separator: " "))")
      }

      if let last = snapshot.lastRunDir { print("\nReceipts: \(last)") }

      if allowDanger, let cmd = snapshot.recommended.command, snapshot.recommended.danger {
        let prompt = "\nThis action may modify studio state. Proceed? [y/N] "
        print(prompt, terminator: "")
        let ans = (readLine() ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if ans == "y" || ans == "yes" {
          _ = try? await OperatorShellService.runProcess(cmd)
        }
      }

      throw ExitCode(3)
    }
  }

  private func resolveWubBinary(repoRoot: String) -> String? {
    let p1 = URL(fileURLWithPath: repoRoot).appendingPathComponent("tools/automation/swift-cli/.build/release/wub").path
    return FileManager.default.isExecutableFile(atPath: p1) ? p1 : nil
  }
}
