import Foundation
import CoreGraphics

final class TeensyActuator: Actuator {
  private let teensy: TeensyClient
  init(teensy: TeensyClient) { self.teensy = teensy }
  func home() throws { try teensy.home() }
  func moveTo(screenPointTopLeft: CGPoint) throws { try teensy.moveRel(dx: Int(screenPointTopLeft.x), dy: Int(screenPointTopLeft.y)) }
  func click() throws { try teensy.click("left") }
  func dblclick() throws { try teensy.dblclick("left") }
  func keyChord(_ chord: String) throws { try teensy.chord(chord) }
  func typeText(_ text: String) throws { try teensy.typeText(text) }
  func sleepMs(_ ms: Int) throws { try teensy.sleep(ms: ms) }
}
