import Foundation
import ScreenCaptureKit
import CoreImage
import CoreGraphics
import CoreMedia

final class FrameCapture {
  private var stream: SCStream?
  private let collector = FrameCollector()

  func start() async throws {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    guard let display = content.displays.first else {
      throw NSError(domain: "FrameCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "No display found"])
    }

    let filter = SCContentFilter(display: display, excludingWindows: [])
    let conf = SCStreamConfiguration()
    conf.width = display.width
    conf.height = display.height
    conf.minimumFrameInterval = CMTime(value: 1, timescale: 5)
    conf.queueDepth = 3
    conf.capturesAudio = false

    let s = SCStream(filter: filter, configuration: conf, delegate: nil)
    try s.addStreamOutput(collector, type: .screen, sampleHandlerQueue: DispatchQueue(label: "sc.frames"))
    try await s.startCapture()
    stream = s
  }

  func stop() async {
    if let s = stream { try? await s.stopCapture() }
    stream = nil
  }

  func latestFrame(timeoutMs: Int = 1500) async throws -> CGImage {
    let frames = try await collector.takeFrames(count: 1, timeoutSec: Double(timeoutMs) / 1000.0)
    if let img = frames.last { return img }
    throw NSError(domain: "FrameCapture", code: 2, userInfo: [NSLocalizedDescriptionKey: "No frames captured"])
  }
}

actor FrameBuffer {
  private var frames: [CGImage] = []

  func add(_ frame: CGImage) {
    frames.append(frame)
    if frames.count > 8 { frames.removeFirst(frames.count - 8) }
  }

  func takeFrames(count: Int, timeoutSec: Double) async throws -> [CGImage] {
    let start = Date()
    while Date().timeIntervalSince(start) < timeoutSec {
      if frames.count >= count { return Array(frames.suffix(count)) }
      try await Task.sleep(nanoseconds: 100_000_000)
    }
    return Array(frames.suffix(count))
  }
}

final class FrameCollector: NSObject, SCStreamOutput {
  private let buffer = FrameBuffer()

  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
    guard type == .screen,
          let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) as? [[SCStreamFrameInfo: Any]],
          attachments.first?[.status] as? Int == SCFrameStatus.complete.rawValue,
          let pixelBuffer = sampleBuffer.imageBuffer else { return }

    let ci = CIImage(cvPixelBuffer: pixelBuffer)
    let ctx = CIContext(options: nil)
    if let cg = ctx.createCGImage(ci, from: ci.extent) {
      Task { await buffer.add(cg) }
    }
  }

  func takeFrames(count: Int, timeoutSec: Double) async throws -> [CGImage] {
    try await buffer.takeFrames(count: count, timeoutSec: timeoutSec)
  }
}
