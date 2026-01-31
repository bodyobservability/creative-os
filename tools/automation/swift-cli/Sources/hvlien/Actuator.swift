import Foundation
import CoreGraphics

protocol Actuator {
  func home() throws
  func moveTo(screenPointTopLeft: CGPoint) throws
  func click() throws
  func dblclick() throws
  func keyChord(_ chord: String) throws
  func typeText(_ text: String) throws
  func sleepMs(_ ms: Int) throws
}
