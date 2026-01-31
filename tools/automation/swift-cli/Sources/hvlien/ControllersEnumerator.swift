import Foundation
import CoreMIDI

func buildControllersInventoryDoc(ableton: String) -> ControllersInventoryDoc {
  var devices: [ControllerDevice] = []
  let n = MIDIGetNumberOfDevices()
  for i in 0..<n {
    let dev = MIDIGetDevice(i)
    if dev == 0 { continue }
    let name = midiString(dev, kMIDIPropertyName) ?? "Unknown MIDI Device"
    let mfr = midiString(dev, kMIDIPropertyManufacturer)
    let model = midiString(dev, kMIDIPropertyModel)
    var ins: [MidiEndpoint] = []
    var outs: [MidiEndpoint] = []
    let ec = MIDIDeviceGetNumberOfEntities(dev)
    for ei in 0..<ec {
      let ent = MIDIDeviceGetEntity(dev, ei)
      for si in 0..<MIDIEntityGetNumberOfSources(ent) {
        let src = MIDIEntityGetSource(ent, si)
        ins.append(MidiEndpoint(id: "in_\(i)_\(ei)_\(si)", displayName: midiString(src, kMIDIPropertyName) ?? "Source", normName: HVLIENNormV1.normNameV1(midiString(src, kMIDIPropertyName)), direction: "input", uniqueId: midiInt(src, kMIDIPropertyUniqueID)))
      }
      for di in 0..<MIDIEntityGetNumberOfDestinations(ent) {
        let dst = MIDIEntityGetDestination(ent, di)
        outs.append(MidiEndpoint(id: "out_\(i)_\(ei)_\(di)", displayName: midiString(dst, kMIDIPropertyName) ?? "Dest", normName: HVLIENNormV1.normNameV1(midiString(dst, kMIDIPropertyName)), direction: "output", uniqueId: midiInt(dst, kMIDIPropertyUniqueID)))
      }
    }
    devices.append(ControllerDevice(id: "dev_\(UUID().uuidString)", displayName: name, normName: HVLIENNormV1.normNameV1(name), manufacturer: mfr, model: model, endpointsIn: ins, endpointsOut: outs))
  }
  return ControllersInventoryDoc(schemaVersion: 1, generatedAt: ISO8601DateFormatter().string(from: Date()), environment: ["os":"macos","ableton":ableton], devices: devices)
}

private func midiString(_ obj: MIDIObjectRef, _ prop: CFString) -> String? {
  var cf: Unmanaged<CFString>?
  let s = MIDIObjectGetStringProperty(obj, prop, &cf)
  if s != noErr { return nil }
  return cf?.takeRetainedValue() as String?
}
private func midiInt(_ obj: MIDIObjectRef, _ prop: CFString) -> Int32? {
  var v: Int32 = 0
  let s = MIDIObjectGetIntegerProperty(obj, prop, &v)
  return s == noErr ? v : nil
}
