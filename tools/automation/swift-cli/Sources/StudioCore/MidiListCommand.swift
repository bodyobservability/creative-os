import Foundation
import ArgumentParser
import CoreMIDI

struct MidiList: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "midi",
    abstract: "MIDI utilities",
    subcommands: [List.self]
  )

  struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "list",
      abstract: "List available CoreMIDI destinations (outputs)"
    )

    func run() throws {
      let n = MIDIGetNumberOfDestinations()
      print("CoreMIDI Destinations (outputs):")
      if n == 0 {
        print("  (none)")
        return
      }
      for i in 0..<n {
        let e = MIDIGetDestination(i)
        if e == 0 { continue }
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(e, kMIDIPropertyName, &name)
        let s = (name?.takeRetainedValue() as String?) ?? "<unnamed>"
        print("  - [\(i)] \(s)")
      }
    }
  }
}
