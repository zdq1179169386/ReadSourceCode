/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageCompat.h"

typedef NS_ENUM(NSUInteger, SDImageCacheConfigExpireType) {
    /**
     * When the image is accessed it will update this value
     */
    SDImageCacheConfigExpireTypeAccessDate,
    /**
     * The image was obtained from the disk cache (Default)
     */
    SDImageCacheConfigExpireTypeModificationDate
};

@interface SDImageCacheConfig : NSObject

/**
 * Decompressing images that are downloaded and cached can improve performance but can consume lot of memory.
 * Defaults to YES. Set this to NO if you are experiencing a crash due to excessive memory consumption.
 */
//解压缩下载和缓存的图像可以提高性能，但会占用大量内存，
//默认为YES。如果由于过多的内存消耗而遇到崩溃，请将此项设置为NO
@property (assign, nonatomic) BOOL shouldDecompressImages;

/**
 * Whether or not to disable iCloud backup
 * Defaults to YES.
 */
//是否禁用iCloud备份
@property (assign, nonatomic) BOOL shouldDisableiCloud;

/**
 * Whether or not to use memory cache
 * @note When the memory cache is disabled, the weak memory cache will also be disabled.
 * Defaults to YES.
 */
//使用内存缓图片（默认为YES），禁用内存高速缓存时，也会禁用弱内存高速缓存
@property (assign, nonatomic) BOOL shouldCacheImagesInMemory;

/**
 * The option to control weak memory cache for images. When enable, `SDImageCache`'s memory cache will use a weak maptable to store the image at the same time when it stored to memory, and get removed at the same time.
 * However when memory warning is triggered, since the weak maptable does not hold a strong reference to image instacnce, even when the memory cache itself is purged, some images which are held strongly by UIImageViews or other live instances can be recovered again, to avoid later re-query from disk cache or network. This may be helpful for the case, for example, when app enter background and memory is purged, cause cell flashing after re-enter foreground.
 * Defautls to YES. You can change this option dynamically.
 */
/*
 控制图像弱内存缓存的选项。当启用时，' SDImageCache '的内存缓存将使用一个弱映射表来存储图像，同时将其存储到内存中，同时将其删除。
 然而当触发内存警告,由于弱maptable不举行一个强引用instacnce形象,即使在内存缓存本身是净化,一些图像由uiimageview持有强烈或其他生活实例可以再次恢复,避免后重新查询缓存从磁盘或网络。这对于以下情况可能会有所帮助，例如，当app进入后台，内存被清空时，重新进入前台会导致单元格闪烁。
 */
@property (assign, nonatomic) BOOL shouldUseWeakMemoryCache;

/**
 * The reading options while reading cache from disk.
 * Defaults to 0. You can set this to `NSDataReadingMappedIfSafe` to improve performance.
 */
//默认是 NSDataReadingMappedIfSafe ：使用这个参数后，iOS就不会把整个文件全部读取的内存了，而是将文件映射到进程的地址空间中，这么做并不会占用实际内存。这样就可以解决内存满的问题
@property (assign, nonatomic) NSDataReadingOptions diskCacheReadingOptions;

/**
 * The writing options while writing cache to disk.
 * Defaults to `NSDataWritingAtomic`. You can set this to `NSDataWritingWithoutOverwriting` to prevent overwriting an existing file.
 */
//默认是 NSDataWritingAtomic， 您可以将其设置为“NSDataWritingWithoutOverwriting”以防止覆盖现有文件
@property (assign, nonatomic) NSDataWritingOptions diskCacheWritingOptions;

/**
 * The maximum length of time to keep an image in the cache, in seconds.
 */
//在缓存中保留一张图片的最大时间长度，单位为秒。
@property (assign, nonatomic) NSInteger maxCacheAge;

/**
 * The maximum size of the cache, in bytes.
 */
//缓存的最大值，单位字节。
@property (assign, nonatomic) NSUInteger maxCacheSize;

/**
 * The attribute which the clear cache will be checked against when clearing the disk cache
 * Default is Modified Date
 */
//缓存配置过期类型，枚举
@property (assign, nonatomic) SDImageCacheConfigExpireType diskCacheExpireType;

@end
