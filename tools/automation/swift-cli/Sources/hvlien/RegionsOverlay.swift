import Foundation
import CoreGraphics

enum RegionsOverlay {
  static func drawAllRegions(on img: CGImage, regions: RegionsV1) -> CGImage? {
    let w = img.width, h = img.height
    guard let cs = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    ctx.setLineWidth(3)
    for k in regions.regions.keys.sorted() {
      guard let r = regions.cgRectTopLeft(k) else { continue }
      let ry = CGFloat(h) - r.origin.y - r.size.height
      let dr = CGRect(x: r.origin.x, y: ry, width: r.size.width, height: r.size.height)
      ctx.setStrokeColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
      ctx.stroke(dr)
    }
    return ctx.makeImage()
  }
}
