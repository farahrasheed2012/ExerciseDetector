#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

NS_ASSUME_NONNULL_BEGIN

@interface EdgeImpulseWrapper : NSObject

/// Initialize the EdgeImpulse classifier
- (instancetype)init;

/// Classify an image from a CVPixelBuffer
/// @param pixelBuffer The camera frame to classify
/// @return Dictionary with predictions: @{@"Arm Raise": @0.85, @"Standing": @0.10, @"Lunge": @0.05}
- (NSDictionary<NSString *, NSNumber *> *)classifyImage:(CVPixelBufferRef)pixelBuffer;

/// Get the model's expected input width
- (int)getInputWidth;

/// Get the model's expected input height
- (int)getInputHeight;

@end

NS_ASSUME_NONNULL_END
