#import "AnchorMatcherBridge.h"
#import <opencv2/imgproc.hpp>
#import <opencv2/imgcodecs.hpp>
#import <opencv2/core.hpp>

@implementation AnchorMatchResult
@end

static cv::Mat CGImageToMatGray(CGImageRef image) {
  const size_t width = CGImageGetWidth(image);
  const size_t height = CGImageGetHeight(image);
  cv::Mat rgba((int)height, (int)width, CV_8UC4);
  CGContextRef ctx = CGBitmapContextCreate(
    rgba.data, width, height, 8, rgba.step[0],
    CGImageGetColorSpace(image),
    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault
  );
  CGContextDrawImage(ctx, CGRectMake(0, 0, width, height), image);
  CGContextRelease(ctx);
  cv::Mat gray;
  cv::cvtColor(rgba, gray, cv::COLOR_RGBA2GRAY);
  return gray;
}

static cv::Mat loadGrayImage(NSString *path) {
  return cv::imread(path.UTF8String, cv::IMREAD_GRAYSCALE);
}

@implementation AnchorMatcherBridge

+ (AnchorMatchResult *)matchAnchorId:(NSString *)anchorId
                        templatePath:(NSString *)templatePath
                            maskPath:(NSString *)maskPath
                             fullImg:(CGImageRef)fullImg
                       regionTopLeftX:(double)rx
                       regionTopLeftY:(double)ry
                              regionW:(double)rw
                              regionH:(double)rh {

  if (!fullImg) return nil;

  cv::Mat fullGray = CGImageToMatGray(fullImg);

  int x = (int)rx, y = (int)ry, w = (int)rw, h = (int)rh;
  x = std::max(0, std::min(x, fullGray.cols - 1));
  y = std::max(0, std::min(y, fullGray.rows - 1));
  w = std::max(1, std::min(w, fullGray.cols - x));
  h = std::max(1, std::min(h, fullGray.rows - y));
  cv::Mat region = fullGray(cv::Rect(x, y, w, h));

  cv::Mat templ = loadGrayImage(templatePath);
  if (templ.empty()) return nil;
  if (region.cols < templ.cols || region.rows < templ.rows) return nil;

  cv::Mat mask;
  if (maskPath && maskPath.length > 0) {
    mask = cv::imread(maskPath.UTF8String, cv::IMREAD_GRAYSCALE);
    if (!mask.empty() && mask.size() != templ.size()) {
      cv::resize(mask, mask, templ.size(), 0, 0, cv::INTER_NEAREST);
    }
  }

  cv::Mat result;
  int method = cv::TM_CCOEFF_NORMED;
  if (!mask.empty()) cv::matchTemplate(region, templ, result, method, mask);
  else cv::matchTemplate(region, templ, result, method);

  double minVal, maxVal;
  cv::Point minLoc, maxLoc;
  cv::minMaxLoc(result, &minVal, &maxVal, &minLoc, &maxLoc);

  AnchorMatchResult *out = [AnchorMatchResult new];
  out.anchorId = anchorId;
  out.score = maxVal;
  out.x = x + maxLoc.x;
  out.y = y + maxLoc.y;
  out.w = templ.cols;
  out.h = templ.rows;
  return out;
}

@end
