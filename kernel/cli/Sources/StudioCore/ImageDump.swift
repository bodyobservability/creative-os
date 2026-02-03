import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageDump {
  static func savePNG(_ img: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
      throw NSError(domain: "ImageDump", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create image destination"])
    }
    CGImageDestinationAddImage(dest, img, nil)
    guard CGImageDestinationFinalize(dest) else {
      throw NSError(domain: "ImageDump", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not finalize PNG"])
    }
  }
}
