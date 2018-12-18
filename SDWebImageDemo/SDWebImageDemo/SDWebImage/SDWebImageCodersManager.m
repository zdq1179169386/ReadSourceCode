/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageCodersManager.h"
#import "SDWebImageImageIOCoder.h"
#import "SDWebImageGIFCoder.h"
#ifdef SD_WEBP
#import "SDWebImageWebPCoder.h"
#endif
#import "UIImage+MultiFormat.h"

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);

@interface SDWebImageCodersManager ()

@property (nonatomic, strong, nonnull) dispatch_semaphore_t codersLock;

@end

@implementation SDWebImageCodersManager

+ (nonnull instancetype)sharedInstance {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        // initialize with default coders
        NSMutableArray<id<SDWebImageCoder>> *mutableCoders = [@[[SDWebImageImageIOCoder sharedCoder]] mutableCopy];
#ifdef SD_WEBP
        [mutableCoders addObject:[SDWebImageWebPCoder sharedCoder]];
#endif
        _coders = [mutableCoders copy];
//        信号量为1
        _codersLock = dispatch_semaphore_create(1);
    }
    return self;
}

#pragma mark - Coder IO operations

- (void)addCoder:(nonnull id<SDWebImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(SDWebImageCoder)]) {
        return;
    }
    LOCK(self.codersLock);
    NSMutableArray<id<SDWebImageCoder>> *mutableCoders = [self.coders mutableCopy];
    if (!mutableCoders) {
        mutableCoders = [NSMutableArray array];
    }
    [mutableCoders addObject:coder];
    self.coders = [mutableCoders copy];
    UNLOCK(self.codersLock);
}

- (void)removeCoder:(nonnull id<SDWebImageCoder>)coder {
    if (![coder conformsToProtocol:@protocol(SDWebImageCoder)]) {
        return;
    }
    LOCK(self.codersLock);
    NSMutableArray<id<SDWebImageCoder>> *mutableCoders = [self.coders mutableCopy];
    [mutableCoders removeObject:coder];
    self.coders = [mutableCoders copy];
    UNLOCK(self.codersLock);
}

#pragma mark - SDWebImageCoder
//该图片是否可以编码
- (BOOL)canDecodeFromData:(NSData *)data {
    LOCK(self.codersLock);
    NSArray<id<SDWebImageCoder>> *coders = self.coders;
    UNLOCK(self.codersLock);
    for (id<SDWebImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            return YES;
        }
    }
    return NO;
}
//该图片是否可以编码
- (BOOL)canEncodeToFormat:(SDImageFormat)format {
    LOCK(self.codersLock);
    NSArray<id<SDWebImageCoder>> *coders = self.coders;
    UNLOCK(self.codersLock);
    for (id<SDWebImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return YES;
        }
    }
    return NO;
}
//判断是否可以解码，如果可以，将图像解码
- (UIImage *)decodedImageWithData:(NSData *)data {
    LOCK(self.codersLock);
    NSArray<id<SDWebImageCoder>> *coders = self.coders;
    UNLOCK(self.codersLock);
    for (id<SDWebImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:data]) {
            return [coder decodedImageWithData:data];
        }
    }
    return nil;
}
//使用原始图像和图像数据解压缩图像
- (UIImage *)decompressedImageWithImage:(UIImage *)image
                                   data:(NSData *__autoreleasing  _Nullable *)data
                                options:(nullable NSDictionary<NSString*, NSObject*>*)optionsDict {
    if (!image) {
        return nil;
    }
//    这里使用信号量进行阻塞，codersLock 为 1， 保证当前只有一条线程访问 coders 这个数组
    LOCK(self.codersLock);
    NSArray<id<SDWebImageCoder>> *coders = self.coders;
    UNLOCK(self.codersLock);
//    reverseObjectEnumerator ： 倒序的数组
    for (id<SDWebImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canDecodeFromData:*data]) {
            UIImage *decompressedImage = [coder decompressedImageWithImage:image data:data options:optionsDict];
            decompressedImage.sd_imageFormat = image.sd_imageFormat;
            return decompressedImage;
        }
    }
    return nil;
}

- (NSData *)encodedDataWithImage:(UIImage *)image format:(SDImageFormat)format {
    if (!image) {
        return nil;
    }
    LOCK(self.codersLock);
    NSArray<id<SDWebImageCoder>> *coders = self.coders;
    UNLOCK(self.codersLock);
    for (id<SDWebImageCoder> coder in coders.reverseObjectEnumerator) {
        if ([coder canEncodeToFormat:format]) {
            return [coder encodedDataWithImage:image format:format];
        }
    }
    return nil;
}

@end
