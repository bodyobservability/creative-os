import Foundation
import CoreMIDI

final class MidiCCSender {
  private var client = MIDIClientRef()
  private var outPort = MIDIPortRef()
  private var dest: MIDIEndpointRef = 0

  init(portNameContains: String) throws {
    var c = MIDIClientRef()
    var status = MIDIClientCreate("WUB-MIDI-Client" as CFString, nil, nil, &c)
    guard status == noErr else { throw NSError(domain: "MidiCCSender", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "MIDIClientCreate failed"]) }
    client = c

    var p = MIDIPortRef()
    status = MIDIOutputPortCreate(client, "WUB-MIDI-Out" as CFString, &p)
    guard status == noErr else { throw NSError(domain: "MidiCCSender", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "MIDIOutputPortCreate failed"]) }
    outPort = p

    // Find destination
    let n = MIDIGetNumberOfDestinations()
    var found: MIDIEndpointRef = 0
    for i in 0..<n {
      let e = MIDIGetDestination(i)
      if e == 0 { continue }
      var name: Unmanaged<CFString>?
      MIDIObjectGetStringProperty(e, kMIDIPropertyName, &name)
      let s = (name?.takeRetainedValue() as String?) ?? ""
      if s.lowercased().contains(portNameContains.lowercased()) {
        found = e
        break
      }
    }
    if found == 0 {
      throw NSError(domain: "MidiCCSender", code: 404, userInfo: [NSLocalizedDescriptionKey: "No MIDI destination matching '\(portNameContains)'. Enable IAC Driver or choose correct port."])
    }
    dest = found
  }

  func sendCC(cc: Int, value: Int, channel: Int) throws {
    let ch = max(1, min(channel, 16)) - 1
    let statusByte = UInt8(0xB0 | UInt8(ch))
    let d1 = UInt8(max(0, min(cc, 127)))
    let d2 = UInt8(max(0, min(value, 127)))

    var pktList = MIDIPacketList()
    let data: [UInt8] = [statusByte, d1, d2]
    data.withUnsafeBytes { bytes in
      let packet = MIDIPacketListInit(&pktList)
      _ = MIDIPacketListAdd(&pktList, MemoryLayout<MIDIPacketList>.size, packet, 0, bytes.count, bytes.bindMemory(to: UInt8.self).baseAddress!)
    }
    let status = MIDISend(outPort, dest, &pktList)
    guard status == noErr else { throw NSError(domain: "MidiCCSender", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "MIDISend failed"]) }
  }

  deinit {
    if outPort != 0 { MIDIPortDispose(outPort) }
    if client != 0 { MIDIClientDispose(client) }
  }
}
