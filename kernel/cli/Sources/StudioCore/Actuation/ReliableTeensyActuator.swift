import Foundation
import CoreGraphics

final class ReliableTeensyActuator: Actuator {
  private var devicePath: String?
  private var client: TeensyClient?
  private var lastPing: Date = .distantPast
  private let lock = NSLock()

  init(devicePath: String?) throws {
    self.devicePath = devicePath
    try ensureConnected()
  }

  func home() throws { try withClient { try $0.home() } }

  func moveTo(screenPointTopLeft: CGPoint) throws {
    try withClient { try $0.moveRel(dx: Int(screenPointTopLeft.x), dy: Int(screenPointTopLeft.y)) }
  }

  func click() throws { try withClient { try $0.click("left") } }
  func dblclick() throws { try withClient { try $0.dblclick("left") } }
  func keyChord(_ chord: String) throws { try withClient { try $0.chord(chord) } }
  func typeText(_ text: String) throws { try withClient { try $0.typeText(text) } }
  func sleepMs(_ ms: Int) throws { try withClient { try $0.sleep(ms: ms) } }

  private func withClient<T>(_ f: (TeensyClient) throws -> T) throws -> T {
    lock.lock(); defer { lock.unlock() }
    do {
      try healthPingIfNeeded()
      guard let c = client else { try ensureConnected(); return try f(client!) }
      return try f(c)
    } catch {
      try ensureConnected(force: true)
      guard let c2 = client else { throw error }
      return try f(c2)
    }
  }

  private func ensureConnected(force: Bool = false) throws {
    if client != nil && !force { return }
    let path = devicePath ?? TeensyDetect.autoDetectDevicePath()
    guard let p = path else {
      throw NSError(domain: "ReliableTeensyActuator", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Teensy device detected (/dev/cu.usbmodem*)."])
    }
    devicePath = p
    client = try TeensyClient(devicePath: p)
    try? client?.ping()
    lastPing = Date()
  }

  private func healthPingIfNeeded() throws {
    let now = Date()
    if now.timeIntervalSince(lastPing) < 2.0 { return }
    guard let c = client else { try ensureConnected(); return }
    try c.ping()
    lastPing = now
  }
}
