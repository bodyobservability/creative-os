import Foundation
import CoreGraphics

enum ScreenMapper {
  static func cropTopLeft(img: CGImage, rectTopLeft: CGRect) -> CGImage {
    let imgH = CGFloat(img.height)
    let cgRect = CGRect(
      x: rectTopLeft.origin.x,
      y: imgH - rectTopLeft.origin.y - rectTopLeft.size.height,
      width: rectTopLeft.size.width,
      height: rectTopLeft.size.height
    ).integral
    return img.cropping(to: cgRect) ?? img
  }

  static func regionPointToScreen(regionRectTopLeft: CGRect, pointInRegion: CGPoint) -> CGPoint {
    CGPoint(x: regionRectTopLeft.origin.x + pointInRegion.x,
            y: regionRectTopLeft.origin.y + pointInRegion.y)
  }
}
