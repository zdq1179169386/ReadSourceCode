/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageCoder.h"

NSString * const SDWebImageCoderScaleDownLargeImagesKey = @"scaleDownLargeImages";

CGColorSpaceRef SDCGColorSpaceGetDeviceRGB(void) {
    static CGColorSpaceRef colorSpace;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        colorSpace = CGColorSpaceCreateDeviceRGB();
    });
    return colorSpace;
}

BOOL SDCGImageRefContainsAlpha(CGImageRef imageRef) {
    // 我们需要判断image是PNG还是JPEG
    // PNG的图片很容易检测出来，因为它们有一个特定的标示 (http://www.w3.org/TR/PNG-Structure.html)
    // PNG图片的前8个字节不许符合下面这些值(十进制表示)
    // 137 80 78 71 13 10 26 10
    
    // 如果imageData为空l (举个例子，比如image在下载后需要transform，那么就imageData就会为空)
    // 并且image有一个alpha通道, 我们将该image看做PNG以避免透明度(alpha)的丢失（因为JPEG没有透明色）
    if (!imageRef) {
        return NO;
    }
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);
    // 该image中确实有透明信息，就认为image为PNG
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                      alphaInfo == kCGImageAlphaNoneSkipFirst ||
                      alphaInfo == kCGImageAlphaNoneSkipLast);
    return hasAlpha;
}
