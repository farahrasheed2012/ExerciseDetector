#import "EdgeImpulseWrapper.h"

#import "edge-impulse-sdk/classifier/ei_run_classifier.h"
#import "edge-impulse-sdk/dsp/image/image.hpp"
#import "model-parameters/model_metadata.h"

#import <CoreGraphics/CoreGraphics.h>
#import <Accelerate/Accelerate.h>

@implementation EdgeImpulseWrapper

- (instancetype)init {
    self = [super init];
    if (self) {
        NSLog(@"EdgeImpulse wrapper initialized (input: %dx%d)", EI_CLASSIFIER_INPUT_WIDTH, EI_CLASSIFIER_INPUT_HEIGHT);
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

    int targetWidth = EI_CLASSIFIER_INPUT_WIDTH;   // 220
    int targetHeight = EI_CLASSIFIER_INPUT_HEIGHT;  // 220

    // --- Get source pixel data from CVPixelBuffer (BGRA format) ---
    size_t srcWidth = CVPixelBufferGetWidth(pixelBuffer);
    size_t srcHeight = CVPixelBufferGetHeight(pixelBuffer);
    void *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    if (!baseAddress) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        return @{};
    }

    // --- Create CGImage from the BGRA pixel buffer ---
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef srcCtx = CGBitmapContextCreate(
        baseAddress, srcWidth, srcHeight, 8, srcBytesPerRow, colorSpace,
        kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst  // BGRA on little-endian
    );

    if (!srcCtx) {
        CGColorSpaceRelease(colorSpace);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        return @{};
    }

    CGImageRef srcImage = CGBitmapContextCreateImage(srcCtx);
    CGContextRelease(srcCtx);

    // --- Resize to model input dimensions (RGBA byte order) ---
    size_t dstBytesPerRow = 4 * targetWidth;
    unsigned char *resizedData = (unsigned char *)calloc(targetHeight * dstBytesPerRow, 1);

    CGContextRef dstCtx = CGBitmapContextCreate(
        resizedData, targetWidth, targetHeight, 8, dstBytesPerRow, colorSpace,
        kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big  // byte order: R, G, B, X
    );

    CGContextSetInterpolationQuality(dstCtx, kCGInterpolationMedium);
    CGContextDrawImage(dstCtx, CGRectMake(0, 0, targetWidth, targetHeight), srcImage);

    CGImageRelease(srcImage);
    CGContextRelease(dstCtx);
    CGColorSpaceRelease(colorSpace);

    // Done with the pixel buffer
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    // --- Pack pixels as 0x00RRGGBB floats for EdgeImpulse DSP ---
    // The EdgeImpulse image DSP block expects one float per pixel, where each
    // float is a uint32 cast: (R << 16) | (G << 8) | B.
    // Signal total_length = number of pixels = width * height.
    size_t pixelCount = targetWidth * targetHeight;  // 48400
    float *features = (float *)malloc(pixelCount * sizeof(float));

    for (size_t i = 0; i < pixelCount; i++) {
        uint8_t r = resizedData[i * 4 + 0];
        uint8_t g = resizedData[i * 4 + 1];
        uint8_t b = resizedData[i * 4 + 2];
        features[i] = (float)((uint32_t)(r << 16) | (uint32_t)(g << 8) | (uint32_t)b);
    }

    free(resizedData);

    // --- Create EdgeImpulse signal ---
    signal_t signal;
    signal.total_length = pixelCount;  // Must be EI_CLASSIFIER_DSP_INPUT_FRAME_SIZE (48400)
    signal.get_data = [features](size_t offset, size_t length, float *out_ptr) -> int {
        memcpy(out_ptr, features + offset, length * sizeof(float));
        return 0;
    };

    // --- Run classifier ---
    ei_impulse_result_t result = {0};
    EI_IMPULSE_ERROR res = run_classifier(&signal, &result, false);

    free(features);

    if (res != EI_IMPULSE_OK) {
        NSLog(@"Classification failed with error: %d", res);
        return @{};
    }

    // --- Parse results into dictionary ---
    NSMutableDictionary *predictions = [NSMutableDictionary dictionary];
    for (size_t i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
        NSString *label = [NSString stringWithUTF8String:result.classification[i].label];
        NSNumber *value = @(result.classification[i].value);
        predictions[label] = value;
    }

    return predictions;
}

@end
