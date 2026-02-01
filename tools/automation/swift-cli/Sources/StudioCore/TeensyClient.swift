import Foundation
import Darwin

final class TeensyClient {
  enum TeensyError: Error { case openFailed(String), writeFailed, readFailed, badResponse(String) }

  private let handle: FileHandle
  private var seq: Int = 1
  private let lock = NSLock()

  init(devicePath: String) throws {
    let fd = open(devicePath, O_RDWR | O_NOCTTY | O_SYNC)
    guard fd >= 0 else { throw TeensyError.openFailed("Unable to open \(devicePath)") }

    var tio = termios()
    tcgetattr(fd, &tio)
    cfsetispeed(&tio, speed_t(B115200))
    cfsetospeed(&tio, speed_t(B115200))
    tio.c_cflag = tcflag_t(CS8 | CLOCAL | CREAD)
    tio.c_iflag = 0
    tio.c_oflag = 0
    tio.c_lflag = 0
    tio.c_cc.16 = 0  // VMIN
    tio.c_cc.17 = 10 // VTIME (1.0s)
    tcsetattr(fd, TCSANOW, &tio)

    self.handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
  }

  func ping() throws { _ = try send("PING") }
  func abort() throws { _ = try send("ABORT") }
  func home() throws { _ = try send("HOME") }
  func moveRel(dx: Int, dy: Int) throws { _ = try send("MOVE_REL \(dx) \(dy)") }
  func click(_ button: String = "left") throws { _ = try send("CLICK \(button)") }
  func dblclick(_ button: String = "left") throws { _ = try send("DBLCLICK \(button)") }
  func chord(_ chord: String) throws { _ = try send("CHORD \(chord)") }
  func sleep(ms: Int) throws { _ = try send("SLEEP \(ms)") }

  func typeText(_ text: String) throws {
    let b64 = Data(text.utf8).base64EncodedString()
    _ = try send("TYPE \(b64)")
  }

  @discardableResult
  private func send(_ cmd: String) throws -> String {
    lock.lock(); defer { lock.unlock() }
    let mySeq = seq; seq += 1
    let line = "\(mySeq) \(cmd)\n"
    guard let data = line.data(using: .utf8) else { throw TeensyError.writeFailed }
    try handle.write(contentsOf: data)

    let resp = try readLine(timeoutMs: 2000)
    guard resp.hasPrefix("\(mySeq) ") else { throw TeensyError.badResponse(resp) }
    if resp.contains(" OK") { return resp }
    throw TeensyError.badResponse(resp)
  }

  private func readLine(timeoutMs: Int) throws -> String {
    let deadline = Date().addingTimeInterval(Double(timeoutMs)/1000.0)
    var buffer = Data()
    while Date() < deadline {
      let chunk = try handle.read(upToCount: 256) ?? Data()
      if chunk.isEmpty {
        Thread.sleep(forTimeInterval: 0.01)
        continue
      }
      buffer.append(chunk)
      if let range = buffer.range(of: Data([0x0A])) {
        let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
        return String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      }
    }
    throw TeensyError.readFailed
  }
}
