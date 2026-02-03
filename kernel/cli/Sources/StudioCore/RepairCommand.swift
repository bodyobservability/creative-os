import Foundation
import ArgumentParser

struct Repair: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "repair",
    abstract: "Run the standard repair recipe: export-all → index build → drift check → drift fix (if needed)."
  )

  @Flag(name: .long, help: "Override station gating (dangerous).")
  var force: Bool = false

  @Option(name: .long, help: "Anchors pack hint for exports and drift.")
  var anchorsPackHint: String = RepoPaths.defaultAnchorsPackHint()

  @Flag(name: .long, help: "Skip confirmation prompt.")
  var yes: Bool = false

  @Flag(name: .long, help: "Overwrite artifacts during export-all.")
  var overwrite: Bool = true

  func run() async throws {
    guard let receipt = try await RepairService.run(config: .init(force: force,
                                                                  anchorsPackHint: anchorsPackHint,
                                                                  yes: yes,
                                                                  overwrite: overwrite,
                                                                  runsDir: RepoPaths.defaultRunsDir())) else {
      return
    }
    if receipt.status == "fail" { throw ExitCode(1) }
  }
}
