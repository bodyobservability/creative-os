import Foundation
import Darwin

enum InputKey {
  case up, down, enter, quit
  case openReceipt, openRun, openFailures
  case toggleAll, refresh, runRecommended, previewDriftPlan, readyVerify, repairRun
  case toggleVoiceMode, toggleStudioMode, toggleLogs, escape, bottom
  case help
  case selectNumber(Int)
  case yes, no
  case none
}

struct InputDecoder {
  static func readKey(timeoutMs: Int) -> InputKey {
    var fds = fd_set()
    FD_ZERO(&fds)
    FD_SET(STDIN_FILENO, &fds)

    var tv = timeval(tv_sec: timeoutMs / 1000, tv_usec: (timeoutMs % 1000) * 1000)
    let rv = select(STDIN_FILENO + 1, &fds, nil, nil, &tv)
    if rv <= 0 { return .none }

    var buf: [UInt8] = [0, 0, 0]
    let n = read(STDIN_FILENO, &buf, 3)
    if n <= 0 { return .none }

    if buf[0] == 0x1B && buf[1] == 0x5B {
      if buf[2] == 0x41 { return .up }
      if buf[2] == 0x42 { return .down }
      return .none
    }
    if buf[0] == 0x1B { return .escape }

    let c = buf[0]

    if c >= asciiByte("1") && c <= asciiByte("9") {
      return .selectNumber(Int(c - asciiByte("0")))
    }

    if c == asciiByte("y") { return .yes }
    if c == asciiByte("n") { return .no }

    if c == 0x20 { return .runRecommended }
    if c == asciiByte("p") { return .previewDriftPlan }
    if c == asciiByte("c") { return .readyVerify }
    if c == asciiByte("g") { return .repairRun }
    if c == asciiByte("v") { return .toggleVoiceMode }
    if c == asciiByte("s") { return .toggleStudioMode }
    if c == asciiByte("l") { return .toggleLogs }
    if c == asciiByte("0") { return .bottom }
    if c == asciiByte("?") { return .help }
    if c == 0x0D || c == 0x0A { return .enter }
    if c == asciiByte("q") { return .quit }
    if c == asciiByte("r") { return .openReceipt }
    if c == asciiByte("f") { return .openFailures }
    if c == asciiByte("o") { return .openRun }
    if c == asciiByte("a") { return .toggleAll }
    if c == asciiByte("R") { return .refresh }
    if c == asciiByte("k") { return .up }
    if c == asciiByte("j") { return .down }
    return .none
  }

  private static func asciiByte(_ s: String) -> UInt8 {
    return s.utf8.first ?? 0
  }
}
