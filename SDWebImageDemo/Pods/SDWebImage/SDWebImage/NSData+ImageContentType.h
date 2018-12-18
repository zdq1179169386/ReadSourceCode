/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Fabrice Aneche
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"
/**
 不同图片类型的枚举
 
 - SDImageFormatUndefined: 未知
 - SDImageFormatJPEG: JPG(FFD8FFE1)
 - SDImageFormatPNG: PNG(89504E47)
 - SDImageFormatGIF: GIF(47494638)
 - SDImageFormatTIFF: TIFF(49492A00或4D4D002A)
 - SDImageFormatWebP: WebP(524946462A73010057454250, 52494646对应ASCII字符为RIFF，57454250对应ASCII字符为WEBP。当第一个字节为52时，如果长度<12 我们就认定为不是图片。因此返回SDImageFormatUndefined。)
 */
typedef NS_ENUM(NSInteger, SDImageFormat) {
    SDImageFormatUndefined = -1,
    SDImageFormatJPEG = 0,
    SDImageFormatPNG,
    SDImageFormatGIF,
    SDImageFormatTIFF,
    SDImageFormatWebP,
    SDImageFormatHEIC
};

@interface NSData (ImageContentType)

/**
 *  Return image format
 *
 *  @param data the input image data
 *
 *  @return the image format as `SDImageFormat` (enum)
 */
+ (SDImageFormat)sd_imageFormatForImageData:(nullable NSData *)data;

/**
 *  Convert SDImageFormat to UTType
 *
 *  @param format Format as SDImageFormat
 *  @return The UTType as CFStringRef
 */
+ (nonnull CFStringRef)sd_UTTypeFromSDImageFormat:(SDImageFormat)format;

/**
 *  Convert UTTyppe to SDImageFormat
 *
 *  @param uttype The UTType as CFStringRef
 *  @return The Format as SDImageFormat
 */
+ (SDImageFormat)sd_imageFormatFromUTType:(nonnull CFStringRef)uttype;

@end
