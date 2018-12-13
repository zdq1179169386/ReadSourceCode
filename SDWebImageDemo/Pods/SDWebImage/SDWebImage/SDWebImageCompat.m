/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageCompat.h"
#import "UIImage+MultiFormat.h"

#if !__has_feature(objc_arc)
    #error SDWebImage is ARC only. Either turn on ARC for the project or use -fobjc-arc flag
#endif

#if !OS_OBJECT_USE_OBJC
    #error SDWebImage need ARC for dispatch object
#endif

// 这个方法为了解决的问题： https://www.jianshu.com/p/680fd15513be
// c 函数
inline UIImage *SDScaledImageForKey(NSString * _Nullable key, UIImage * _Nullable image) {
    if (!image) {
        return nil;
    }
    
#if SD_MAC
    return image;
#elif SD_UIKIT || SD_WATCH
    if ((image.images).count > 0) {
//        这里是gif 的图片
        NSMutableArray<UIImage *> *scaledImages = [NSMutableArray array];

        for (UIImage *tempImage in image.images) {
            [scaledImages addObject:SDScaledImageForKey(key, tempImage)];
        }
        
        UIImage *animatedImage = [UIImage animatedImageWithImages:scaledImages duration:image.duration];
        if (animatedImage) {
            animatedImage.sd_imageLoopCount = image.sd_imageLoopCount;
            animatedImage.sd_imageFormat = image.sd_imageFormat;
        }
        return animatedImage;
    } else {
#if SD_WATCH
        if ([[WKInterfaceDevice currentDevice] respondsToSelector:@selector(screenScale)]) {
#elif SD_UIKIT
        if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
#endif
            // 比如屏幕为320x480时，scale为1，屏幕为640x960时，scale为2
            CGFloat scale = 1;
            // “@2x.png”的长度为7，所以此处添加了这个判断，很巧妙
            if (key.length >= 8) {
                NSRange range = [key rangeOfString:@"@2x."];
                if (range.location != NSNotFound) {
                    scale = 2.0;
                }
                
                range = [key rangeOfString:@"@3x."];
                if (range.location != NSNotFound) {
                    scale = 3.0;
                }
            }
//            返回2倍图和3倍u图，缩放，以及方向
//          imageOrientation 会记住图片一开始的方向，但是重绘之后，这个信息就会被删除，这里以它原来的方向
            UIImage *scaledImage = [[UIImage alloc] initWithCGImage:image.CGImage scale:scale orientation:image.imageOrientation];
            scaledImage.sd_imageFormat = image.sd_imageFormat;
            image = scaledImage;
        }
        return image;
    }
#endif
}

NSString *const SDWebImageErrorDomain = @"SDWebImageErrorDomain";

