import Foundation
import ArgumentParser

struct Session: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "session",
    abstract: "Session compiler (v5+v6 orchestration).",
    subcommands: [Compile.self]
  )

  struct Compile: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "compile",
      abstract: "Compile a session end-to-end: voice handshake, rack install, rack verify."
    )

    @Option(name: .long, help: "Profile id (e.g. bass_v1).")
    var profile: String

    @Option(name: .long, help: "Profile path override (optional).")
    var profilePath: String?

    @Option(name: .long, help: "Anchors pack path override (optional).")
    var anchorsPack: String?

    @Flag(name: .long, help: "Run sweep --fix during voice handshake.")
    var fix: Bool = false

    func run() async throws {
      let receipt = try await SessionService.compile(config: .init(profile: profile,
                                                                   profilePath: profilePath,
                                                                   anchorsPack: anchorsPack,
                                                                   fix: fix,
                                                                   runsDir: "runs"))
      print("\nsession_receipt: runs/\(receipt.runId)/session_receipt.v1.json")
      if receipt.status != "pass" { throw ExitCode(1) }
    }
  }
}
