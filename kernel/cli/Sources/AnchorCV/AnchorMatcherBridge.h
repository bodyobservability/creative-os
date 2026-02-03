#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface AnchorMatchResult : NSObject
@property(nonatomic, copy) NSString *anchorId;
@property(nonatomic, assign) double score;
@property(nonatomic, assign) double x;
@property(nonatomic, assign) double y;
@property(nonatomic, assign) double w;
@property(nonatomic, assign) double h;
@end

@interface AnchorMatcherBridge : NSObject
+ (nullable AnchorMatchResult *)matchAnchorId:(NSString *)anchorId
                                templatePath:(NSString *)templatePath
                                    maskPath:(nullable NSString *)maskPath
                                     fullImg:(CGImageRef)fullImg
                               regionTopLeftX:(double)rx
                               regionTopLeftY:(double)ry
                                      regionW:(double)rw
                                      regionH:(double)rh;
@end

NS_ASSUME_NONNULL_END
