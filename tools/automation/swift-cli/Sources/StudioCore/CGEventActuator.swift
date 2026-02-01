import Foundation
import CoreGraphics

final class CGEventActuator: Actuator {
  func home() throws { try moveTo(screenPointTopLeft: CGPoint(x: 2, y: 2)) }

  func moveTo(screenPointTopLeft: CGPoint) throws {
    let move = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: screenPointTopLeft, mouseButton: .left)
    move?.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.01)
  }

  func click() throws {
    guard let loc = CGEvent(source: nil)?.location else { return }
    let down = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: loc, mouseButton: .left)
    let up = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: loc, mouseButton: .left)
    down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    Thread.sleep(forTimeInterval: 0.02)
  }

  func dblclick() throws {
    try click(); Thread.sleep(forTimeInterval: 0.06); try click()
  }

  func keyChord(_ chord: String) throws {
    // Minimal CMD+A / ESC / CMD+W support via Unicode events. Expand as needed.
    if chord == "ESC" { postKey(53); return }
    if chord == "ENTER" { postKey(36); return }
    if chord == "CMD+A" { postCmdChar("a"); return }
    if chord == "CMD+W" { postCmdChar("w"); return }
    // fallback: type chord literally
    try typeText(chord)
  }

  func typeText(_ text: String) throws {
    for ch in text { postUnicode(ch) }
  }

  func sleepMs(_ ms: Int) throws { Thread.sleep(forTimeInterval: Double(ms) / 1000.0) }

  private func postKey(_ code: CGKeyCode) {
    let d = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)
    let u = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
    d?.post(tap: .cghidEventTap); u?.post(tap: .cghidEventTap)
  }

  private func postCmdChar(_ c: String) {
    let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 55, keyDown: true)
    cmdDown?.post(tap: .cghidEventTap)
    postUnicode(Character(c))
    let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 55, keyDown: false)
    cmdUp?.post(tap: .cghidEventTap)
  }

  private func postUnicode(_ ch: Character) {
    var chars = Array(String(ch).utf16)
    let d = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
    d?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars); d?.post(tap: .cghidEventTap)
    let u = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
    u?.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars); u?.post(tap: .cghidEventTap)
  }
}
