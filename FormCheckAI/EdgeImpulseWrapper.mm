#import "EdgeImpulseWrapper.h"

#import "edge-impulse-sdk/classifier/ei_run_classifier.h"
#import "edge-impulse-sdk/dsp/image/image.hpp"
#import "model-parameters/model_metadata.h"

#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>
#import <UIKit/UIKit.h>

@implementation EdgeImpulseWrapper

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"EdgeImpulse wrapper initialized");
    }
    return self;
}

- (int)getInputWidth {
    return EI_CLASSIFIER_INPUT_WIDTH;
}

- (int)getInputHeight {
    return EI_CLASSIFIER_INPUT_HEIGHT;
}

- (NSDictionary<NSString *, NSNumber *> *)classifyImage:(CVPixelBufferRef)pixelBuffer {

    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    int targetWidth = [self getInputWidth];
    int targetHeight = [self getInputHeight];

    // Convert CVPixelBuffer to UIImage
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);

    // Resize to model input size
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(targetWidth, targetHeight), YES, 1.0);
    [image drawInRect:CGRectMake(0, 0, targetWidth, targetHeight)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    // Convert to RGB pixel array
    CGImageRef resizedCGImage = resizedImage.CGImage;
    size_t bytesPerPixel = 4;
    size_t bytesPerRow = bytesPerPixel * targetWidth;

    unsigned char *rawData = (unsigned char *)malloc(targetHeight * targetWidth * bytesPerPixel);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef bitmapContext = CGBitmapContextCreate(
        rawData,
        targetWidth,
        targetHeight,
        8,
        bytesPerRow,
        colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
    );

    CGContextDrawImage(bitmapContext, CGRectMake(0, 0, targetWidth, targetHeight), resizedCGImage);
    CGContextRelease(bitmapContext);
    CGColorSpaceRelease(colorSpace);

    // Extract RGB values (skip alpha channel)
    size_t featureCount = targetWidth * targetHeight * 3;
    float *features = (float *)malloc(featureCount * sizeof(float));

    for (int i = 0; i < targetWidth * targetHeight; i++) {
        features[i * 3 + 0] = rawData[i * 4 + 0] / 255.0f; // R
        features[i * 3 + 1] = rawData[i * 4 + 1] / 255.0f; // G
        features[i * 3 + 2] = rawData[i * 4 + 2] / 255.0f; // B
    }

    free(rawData);

    // Create EdgeImpulse signal
    signal_t signal;
    signal.total_length = featureCount;
    signal.get_data = [features](size_t offset, size_t length, float *out_ptr) -> int {
        memcpy(out_ptr, features + offset, length * sizeof(float));
        return 0;
    };

    // Run classifier
    ei_impulse_result_t result = {0};
    EI_IMPULSE_ERROR res = run_classifier(&signal, &result, false);

    free(features);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    if (res != EI_IMPULSE_OK) {
        NSLog(@"Classification failed: %d", res);
        return @{};
    }

    // Parse results into dictionary
    NSMutableDictionary *predictions = [NSMutableDictionary dictionary];
    for (size_t i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
        NSString *label = [NSString stringWithUTF8String:result.classification[i].label];
        NSNumber *value = @(result.classification[i].value);
        predictions[label] = value;
    }

    return predictions;
}

@end
