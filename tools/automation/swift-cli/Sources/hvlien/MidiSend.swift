import Foundation
import CoreMIDI

final class MidiSend {
  private var client = MIDIClientRef()
  private var outPort = MIDIPortRef()
  private var dest: MIDIEndpointRef = 0

  init(destNameContains: String) throws {
    var c = MIDIClientRef()
    var status = MIDIClientCreate("HVLIEN-MIDI-Send" as CFString, nil, nil, &c)
    guard status == noErr else { throw NSError(domain: "MidiSend", code: Int(status), userInfo: [NSLocalizedDescriptionKey:"MIDIClientCreate failed"]) }
    client = c

    var p = MIDIPortRef()
    status = MIDIOutputPortCreate(client, "HVLIEN-MIDI-Out" as CFString, &p)
    guard status == noErr else { throw NSError(domain: "MidiSend", code: Int(status), userInfo: [NSLocalizedDescriptionKey:"MIDIOutputPortCreate failed"]) }
    outPort = p

    let n = MIDIGetNumberOfDestinations()
    var found: MIDIEndpointRef = 0
    for i in 0..<n {
      let e = MIDIGetDestination(i)
      if e == 0 { continue }
      var name: Unmanaged<CFString>?
      MIDIObjectGetStringProperty(e, kMIDIPropertyName, &name)
      let s = (name?.takeRetainedValue() as String?) ?? ""
      if s.lowercased().contains(destNameContains.lowercased()) {
        found = e; break
      }
    }
    if found == 0 {
      throw NSError(domain: "MidiSend", code: 404, userInfo: [NSLocalizedDescriptionKey:"No MIDI destination matching '\(destNameContains)'"])
    }
    dest = found
  }

  func sendCC(cc: Int, value: Int, channel: Int) throws {
    let ch = max(1, min(channel, 16)) - 1
    let statusByte = UInt8(0xB0 | UInt8(ch))
    send(bytes: [statusByte, UInt8(clamp7(cc)), UInt8(clamp7(value))])
  }

  func sendNoteOn(note: Int, velocity: Int, channel: Int) throws {
    let ch = max(1, min(channel, 16)) - 1
    let statusByte = UInt8(0x90 | UInt8(ch))
    send(bytes: [statusByte, UInt8(clamp7(note)), UInt8(clamp7(velocity))])
  }

  private func send(bytes: [UInt8]) throws {
    // Build a 64-byte tuple for MIDIPacket. We only use first 3 bytes.
    let b0 = bytes.count > 0 ? bytes[0] : 0
    let b1 = bytes.count > 1 ? bytes[1] : 0
    let b2 = bytes.count > 2 ? bytes[2] : 0

    var pkt = MIDIPacketList(numPackets: 1,
      packet: MIDIPacket(timeStamp: 0, length: UInt16(bytes.count),
        data: (b0,b1,b2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0))
    let st = MIDISend(outPort, dest, &pkt)
    guard st == noErr else { throw NSError(domain: "MidiSend", code: Int(st), userInfo: [NSLocalizedDescriptionKey:"MIDISend failed"]) }
  }

  private func clamp7(_ x: Int) -> Int { max(0, min(127, x)) }

  deinit {
    if outPort != 0 { MIDIPortDispose(outPort) }
    if client != 0 { MIDIClientDispose(client) }
  }
}
