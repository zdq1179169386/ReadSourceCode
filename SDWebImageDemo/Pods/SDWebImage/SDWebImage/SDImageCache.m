/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDImageCache.h"
#import <CommonCrypto/CommonDigest.h>
#import "NSImage+WebCache.h"
#import "SDWebImageCodersManager.h"

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);
// FOUNDATION_STATIC_INLINE表示static __inline__，属于runtime范畴
FOUNDATION_STATIC_INLINE NSUInteger SDCacheCostForImage(UIImage *image) {
#if SD_MAC
    return image.size.height * image.size.width;
#elif SD_UIKIT || SD_WATCH
    return image.size.height * image.size.width * image.scale * image.scale;
#endif
}

// A memory cache which auto purge the cache on memory warning and support weak cache.
@interface SDMemoryCache <KeyType, ObjectType> : NSCache <KeyType, ObjectType>

@end

// Private
@interface SDMemoryCache <KeyType, ObjectType> ()

@property (nonatomic, strong, nonnull) SDImageCacheConfig *config;

/*
 https://www.jianshu.com/p/de71385930ba
 NSHashTable ： 是为了结果可变数组中添加模型，而造成的循环引用，主要决定 NSHashTableWeakMemory
 */
/*
 http://www.isaced.com/post-235.html
 NSDictionary 的key 只适合值类型（比如字符串和数字），当key 如果是对象的时候，这就需要 NSMapTable 类型了
 */

@property (nonatomic, strong, nonnull) NSMapTable<KeyType, ObjectType> *weakCache; // strong-weak cache
@property (nonatomic, strong, nonnull) dispatch_semaphore_t weakCacheLock; // a lock to keep the access to `weakCache` thread-safe

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConfig:(nonnull SDImageCacheConfig *)config;

@end

@implementation SDMemoryCache

// Current this seems no use on macOS (macOS use virtual memory and do not clear cache when memory warning). So we only override on iOS/tvOS platform.
// But in the future there may be more options and features for this subclass.
#if SD_UIKIT

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

- (instancetype)initWithConfig:(SDImageCacheConfig *)config {
    self = [super init];
    if (self) {
        // Use a strong-weak maptable storing the secondary cache. Follow the doc that NSCache does not copy keys
        // This is useful when the memory warning, the cache was purged. However, the image instance can be retained by other instance such as imageViews and alive.
        // At this case, we can sync weak cache back and do not need to load from disk cache
//    使用存储二级缓存的强弱映射表。按照NSCache不复制密钥的文档，    当内存警告，缓存被清除时，这很有用。但是，图像实例可以由其他实例保留，例如imageViews和alive。在这种情况下，我们可以同步弱缓存，而不需要从磁盘缓存加载
// 新增弱缓存 weakCache ： 是为了当内存报警告的时候，删除了nscache 里的东西，但是弱缓存，maptable 的数据是还在的。详见 didReceiveMemoryWarning 的注释
//        表示weakCache变量指向的对象强引用key值，弱引用value值。假如没有其他变量强引用value值，weakCache变量将安全的删除相应的key-value。
        self.weakCache = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory capacity:0];
        
        self.weakCacheLock = dispatch_semaphore_create(1);
        self.config = config;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didReceiveMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification
                                                   object:nil];
    }
    return self;
}
//内存警告的时候，只删除 memoryCache ,不删除 maptable
- (void)didReceiveMemoryWarning:(NSNotification *)notification {
    // Only remove cache, but keep weak cache
    [super removeAllObjects];
}

// `setObject:forKey:` just call this with 0 cost. Override this is enough
- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)g {
    [super setObject:obj forKey:key cost:g];
    if (!self.config.shouldUseWeakMemoryCache) {
        return;
    }
    if (key && obj) {
        // Store weak cache
        LOCK(self.weakCacheLock);
        [self.weakCache setObject:obj forKey:key];
        UNLOCK(self.weakCacheLock);
    }
}

- (id)objectForKey:(id)key {
    id obj = [super objectForKey:key];
    if (!self.config.shouldUseWeakMemoryCache) {
        return obj;
    }
    if (key && !obj) {
        // Check weak cache
        LOCK(self.weakCacheLock);
        obj = [self.weakCache objectForKey:key];
        UNLOCK(self.weakCacheLock);
        if (obj) {
            // Sync cache
            NSUInteger cost = 0;
            if ([obj isKindOfClass:[UIImage class]]) {
                cost = SDCacheCostForImage(obj);
            }
            [super setObject:obj forKey:key cost:cost];
        }
    }
    return obj;
}

- (void)removeObjectForKey:(id)key {
    [super removeObjectForKey:key];
    if (!self.config.shouldUseWeakMemoryCache) {
        return;
    }
    if (key) {
        // Remove weak cache
        LOCK(self.weakCacheLock);
        [self.weakCache removeObjectForKey:key];
        UNLOCK(self.weakCacheLock);
    }
}

- (void)removeAllObjects {
    [super removeAllObjects];
    if (!self.config.shouldUseWeakMemoryCache) {
        return;
    }
//    删除弱缓存
    // Manually remove should also remove weak cache
//    信号量，防止多线程同时访问
    LOCK(self.weakCacheLock);
    [self.weakCache removeAllObjects];
    UNLOCK(self.weakCacheLock);
}

#else

- (instancetype)initWithConfig:(SDImageCacheConfig *)config {
    self = [super init];
    return self;
}

#endif

@end

@interface SDImageCache ()

#pragma mark - Properties
@property (strong, nonatomic, nonnull) SDMemoryCache *memCache;
@property (strong, nonatomic, nonnull) NSString *diskCachePath;
@property (strong, nonatomic, nullable) NSMutableArray<NSString *> *customPaths;
@property (strong, nonatomic, nullable) dispatch_queue_t ioQueue;
@property (strong, nonatomic, nonnull) NSFileManager *fileManager;

@end


@implementation SDImageCache

#pragma mark - Singleton, init, dealloc

+ (nonnull instancetype)sharedImageCache {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (instancetype)init {
    return [self initWithNamespace:@"default"];
}
//根据一个指定的命名空间初始化一个新的存储缓存
- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns {
    NSString *path = [self makeDiskCachePath:ns];
    return [self initWithNamespace:ns diskCacheDirectory:path];
}

- (nonnull instancetype)initWithNamespace:(nonnull NSString *)ns
                       diskCacheDirectory:(nonnull NSString *)directory {
    if ((self = [super init])) {
        NSString *fullNamespace = [@"com.hackemist.SDWebImageCache." stringByAppendingString:ns];
        
        // Create IO serial queue
        _ioQueue = dispatch_queue_create("com.hackemist.SDWebImageCache", DISPATCH_QUEUE_SERIAL);
        
        _config = [[SDImageCacheConfig alloc] init];
        
        // Init the memory cache
        _memCache = [[SDMemoryCache alloc] initWithConfig:_config];
        _memCache.name = fullNamespace;

        // Init the disk cache
        if (directory != nil) {
            //            /Users/qrh/Library/Developer/CoreSimulator/Devices/9975C1C0-939D-44DD-9D1E-0E62598F9440/data/Containers/Data/Application/F1163A6C-6113-4676-819F-3E56875F0D03/Library/Caches/default/com.hackemist.SDWebImageCache.default

            _diskCachePath = [directory stringByAppendingPathComponent:fullNamespace];
        } else {
//            Library/Caches/default
            NSString *path = [self makeDiskCachePath:ns];
            _diskCachePath = path;
        }

        dispatch_sync(_ioQueue, ^{
            self.fileManager = [NSFileManager new];
        });

#if SD_UIKIT
        // Subscribe to app events
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(deleteOldFiles)
                                                     name:UIApplicationWillTerminateNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(backgroundDeleteOldFiles)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
#endif
    }

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Cache paths

- (void)addReadOnlyCachePath:(nonnull NSString *)path {
    if (!self.customPaths) {
        self.customPaths = [NSMutableArray new];
    }

    if (![self.customPaths containsObject:path]) {
        [self.customPaths addObject:path];
    }
}
// 根据key 用md5 加密之后，返回文件名，再拼上路径，，形成这个图片自己的路径.
- (nullable NSString *)cachePathForKey:(nullable NSString *)key inPath:(nonnull NSString *)path {
    NSString *filename = [self cachedFileNameForKey:key];
    return [path stringByAppendingPathComponent:filename];
}
//根据一个指定的key获取默认的缓存路径
- (nullable NSString *)defaultCachePathForKey:(nullable NSString *)key {
    return [self cachePathForKey:key inPath:self.diskCachePath];
}

- (nullable NSString *)cachedFileNameForKey:(nullable NSString *)key {
    const char *str = key.UTF8String;
    if (str == NULL) {
        str = "";
    }
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, (CC_LONG)strlen(str), r);
    NSURL *keyURL = [NSURL URLWithString:key];
    NSString *ext = keyURL ? keyURL.pathExtension : key.pathExtension;
    NSString *filename = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%@",
                          r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10],
                          r[11], r[12], r[13], r[14], r[15], ext.length == 0 ? @"" : [NSString stringWithFormat:@".%@", ext]];
    return filename;
}
// 返回的路径 /Library/Caches/default
- (nullable NSString *)makeDiskCachePath:(nonnull NSString*)fullNamespace {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    return [paths[0] stringByAppendingPathComponent:fullNamespace];
}

#pragma mark - Store Ops
//根据提供的key异步的将一张图片保存到内存和硬盘缓存。
- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key toDisk:YES completion:completionBlock];
}

- (void)storeImage:(nullable UIImage *)image
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    [self storeImage:image imageData:nil forKey:key toDisk:toDisk completion:completionBlock];
}
//根据提供的key异步的将一张图片保存到内存和硬盘缓存。
- (void)storeImage:(nullable UIImage *)image
         imageData:(nullable NSData *)imageData
            forKey:(nullable NSString *)key
            toDisk:(BOOL)toDisk
        completion:(nullable SDWebImageNoParamsBlock)completionBlock {
    if (!image || !key) {
        if (completionBlock) {
            completionBlock();
        }
        return;
    }
    // if memory cache is enabled
    if (self.config.shouldCacheImagesInMemory) {
        // cost 被用来计算缓存中所有对象的代价。当内存受限或者所有缓存对象的总代价超过了最大允许的值时，缓存会移除其中的一些对象。
        // 通常，精确的 cost 应该是对象占用的字节数。
        NSUInteger cost = SDCacheCostForImage(image);
        [self.memCache setObject:image forKey:key cost:cost];
    }
    
    if (toDisk) {
        dispatch_async(self.ioQueue, ^{
            @autoreleasepool {
                NSData *data = imageData;
                if (!data && image) {
                    // If we do not have any data to detect image format, check whether it contains alpha channel to use PNG or JPEG format
                    SDImageFormat format;
                    if (SDCGImageRefContainsAlpha(image.CGImage)) {
                        // 该image中确实有透明信息，就认为image为PNG
                        format = SDImageFormatPNG;
                    } else {
                        format = SDImageFormatJPEG;
                    }
                    data = [[SDWebImageCodersManager sharedInstance] encodedDataWithImage:image format:format];
                }
                [self _storeImageDataToDisk:data forKey:key];
            }
            
            if (completionBlock) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completionBlock();
                });
            }
        });
    } else {
        if (completionBlock) {
            completionBlock();
        }
    }
}

//对外暴露的将 imageData 写到磁盘的方法
- (void)storeImageDataToDisk:(nullable NSData *)imageData forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    dispatch_sync(self.ioQueue, ^{
        [self _storeImageDataToDisk:imageData forKey:key];
    });
}

// Make sure to call form io queue by caller
//将 imageData 写到磁盘中
- (void)_storeImageDataToDisk:(nullable NSData *)imageData forKey:(nullable NSString *)key {
    if (!imageData || !key) {
        return;
    }
    
    if (![self.fileManager fileExistsAtPath:_diskCachePath]) {
//        判断有没有文件夹
        [self.fileManager createDirectoryAtPath:_diskCachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    
    // get cache Path for image key
    NSString *cachePathForKey = [self defaultCachePathForKey:key];
    // transform to NSUrl
    NSURL *fileURL = [NSURL fileURLWithPath:cachePathForKey];
//   diskCacheWritingOptions ：NSDataWritingAtomic
    [imageData writeToURL:fileURL options:self.config.diskCacheWritingOptions error:nil];
    
    // disable iCloud backup
    if (self.config.shouldDisableiCloud) {
//        默认禁用iCloud 备份
        [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}

#pragma mark - Query and Retrieve Ops
//异步检查在硬盘缓存图片是否已经存在（不加载图片）。注意： 完成块一只在主线程中执行
- (void)diskImageExistsWithKey:(nullable NSString *)key completion:(nullable SDWebImageCheckCacheCompletionBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        BOOL exists = [self _diskImageDataExistsWithKey:key];
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock(exists);
            });
        }
    });
}

- (BOOL)diskImageDataExistsWithKey:(nullable NSString *)key {
    if (!key) {
        return NO;
    }
    __block BOOL exists = NO;
    dispatch_sync(self.ioQueue, ^{
        exists = [self _diskImageDataExistsWithKey:key];
    });
    
    return exists;
}

// Make sure to call form io queue by caller
- (BOOL)_diskImageDataExistsWithKey:(nullable NSString *)key {
    if (!key) {
        return NO;
    }
    BOOL exists = [self.fileManager fileExistsAtPath:[self defaultCachePathForKey:key]];
    
    // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
    // checking the key with and without the extension
    if (!exists) {
//     stringByDeletingPathExtension： 删除路径最后部分的扩展名
        exists = [self.fileManager fileExistsAtPath:[self defaultCachePathForKey:key].stringByDeletingPathExtension];
    }
    
    return exists;
}

- (nullable NSData *)diskImageDataForKey:(nullable NSString *)key {
    if (!key) {
        return nil;
    }
    __block NSData *imageData = nil;
    dispatch_sync(self.ioQueue, ^{
        imageData = [self diskImageDataBySearchingAllPathsForKey:key];
    });
    
    return imageData;
}
//异步查询内存缓存
- (nullable UIImage *)imageFromMemoryCacheForKey:(nullable NSString *)key {
    return [self.memCache objectForKey:key];
}
//异步查询硬盘缓存
- (nullable UIImage *)imageFromDiskCacheForKey:(nullable NSString *)key {
    UIImage *diskImage = [self diskImageForKey:key];
    //    shouldCacheImagesInMemory: 这个属性的意思应该是否 仅仅是 内存缓存 ，如果当前设置的是内存缓存，就把从硬盘中查询的图片，加载到内存中
    if (diskImage && self.config.shouldCacheImagesInMemory) {
        NSUInteger cost = SDCacheCostForImage(diskImage);
        [self.memCache setObject:diskImage forKey:key cost:cost];
    }

    return diskImage;
}
//从缓存中取图片
- (nullable UIImage *)imageFromCacheForKey:(nullable NSString *)key {
    // First check the in-memory cache...
//    先从内存中找，内存中没有再从硬盘中找
    UIImage *image = [self imageFromMemoryCacheForKey:key];
    if (image) {
        return image;
    }
    
    // Second check the disk cache...
    image = [self imageFromDiskCacheForKey:key];
    return image;
}
// 根据key 从磁盘中取 图片的data 数据，做了大图的内存暴增 处理
- (nullable NSData *)diskImageDataBySearchingAllPathsForKey:(nullable NSString *)key {
    NSString *defaultPath = [self defaultCachePathForKey:key];
    NSData *data = [NSData dataWithContentsOfFile:defaultPath options:self.config.diskCacheReadingOptions error:nil];
    if (data) {
        return data;
    }

    // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
    // checking the key with and without the extension
//  diskCacheReadingOptions 默认是 NSDataReadingMappedIfSafe ：使用这个参数后，iOS就不会把整个文件全部读取的内存了，而是将文件映射到进程的地址空间中，这么做并不会占用实际内存。这样就可以解决内存满的问题
    data = [NSData dataWithContentsOfFile:defaultPath.stringByDeletingPathExtension options:self.config.diskCacheReadingOptions error:nil];
    if (data) {
        return data;
    }

    NSArray<NSString *> *customPaths = [self.customPaths copy];
    for (NSString *path in customPaths) {
        NSString *filePath = [self cachePathForKey:key inPath:path];
        NSData *imageData = [NSData dataWithContentsOfFile:filePath options:self.config.diskCacheReadingOptions error:nil];
        if (imageData) {
            return imageData;
        }

        // fallback because of https://github.com/rs/SDWebImage/pull/976 that added the extension to the disk file name
        // checking the key with and without the extension
        imageData = [NSData dataWithContentsOfFile:filePath.stringByDeletingPathExtension options:self.config.diskCacheReadingOptions error:nil];
        if (imageData) {
            return imageData;
        }
    }

    return nil;
}

- (nullable UIImage *)diskImageForKey:(nullable NSString *)key {
    NSData *data = [self diskImageDataForKey:key];
    return [self diskImageForKey:key data:data];
}

- (nullable UIImage *)diskImageForKey:(nullable NSString *)key data:(nullable NSData *)data {
    return [self diskImageForKey:key data:data options:0];
}
//根据key 或 data 解压图片，大图做了解压缩处理
- (nullable UIImage *)diskImageForKey:(nullable NSString *)key data:(nullable NSData *)data options:(SDImageCacheOptions)options {
    if (data) {
//      根据data  获取解码的图片
        UIImage *image = [[SDWebImageCodersManager sharedInstance] decodedImageWithData:data];
        image = [self scaledImageForKey:key image:image];
        if (self.config.shouldDecompressImages) {
            BOOL shouldScaleDown = options & SDImageCacheScaleDownLargeImages;
//      大图解压缩
            image = [[SDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&data options:@{SDWebImageCoderScaleDownLargeImagesKey: @(shouldScaleDown)}];
        }
        return image;
    } else {
        return nil;
    }
}
// 处理图片，返回2倍还是3倍图，设置图片的缩放，以及方向
- (nullable UIImage *)scaledImageForKey:(nullable NSString *)key image:(nullable UIImage *)image {
    return SDScaledImageForKey(key, image);
}
//异步查询缓存并在完成后调用完成块
- (NSOperation *)queryCacheOperationForKey:(NSString *)key done:(SDCacheQueryCompletedBlock)doneBlock {
    return [self queryCacheOperationForKey:key options:0 done:doneBlock];
}
// options 默认的是：SDImageCacheQueryDataWhenInMemory
- (nullable NSOperation *)queryCacheOperationForKey:(nullable NSString *)key options:(SDImageCacheOptions)options done:(nullable SDCacheQueryCompletedBlock)doneBlock {
    if (!key) {
        if (doneBlock) {
            doneBlock(nil, nil, SDImageCacheTypeNone);
        }
        return nil;
    }
    
//     First check the in-memory cache...
//    先从内存中找
    UIImage *image = [self imageFromMemoryCacheForKey:key];
//     options 和 SDImageCacheQueryDataWhenInMemory 按位与 ，结果是0 ，取反结果是 1
//    NSLog(@"%@",@(!(options & SDImageCacheQueryDataWhenInMemory)));
    BOOL shouldQueryMemoryOnly = (image && !(options & SDImageCacheQueryDataWhenInMemory));
    if (shouldQueryMemoryOnly) {
        if (doneBlock) {
            doneBlock(image, nil, SDImageCacheTypeMemory);
        }
        return nil;
    }
//   新建线程，走到这，一种情况是： 说明内存中没有图片，需要去硬盘中取 ，还有种情况就是设置了 SDImageCacheQueryDataWhenInMemory，强制要求查询磁盘数据
    NSOperation *operation = [NSOperation new];
    void(^queryDiskBlock)(void) =  ^{
        if (operation.isCancelled) {
            // do not call the completion if cancelled
            //        如果线程取消就返回
            return;
        }
        //     使用 @autoreleasepool : 应该也是防止大图的内存暴增问题
        @autoreleasepool {
            NSData *diskData = [self diskImageDataBySearchingAllPathsForKey:key];
            UIImage *diskImage;
            SDImageCacheType cacheType = SDImageCacheTypeDisk;
            if (image) {
//                如果image 存在，就是上面说的第二种情况，强制要求查询磁盘数据
                // the image is from in-memory cache
                diskImage = image;
                cacheType = SDImageCacheTypeMemory;
            } else if (diskData) {
                // decode image data only if in-memory cache missed
//               仅在内存缓存未命中时才解码图像数据
                diskImage = [self diskImageForKey:key data:diskData options:options];
                if (diskImage && self.config.shouldCacheImagesInMemory) {
                    NSUInteger cost = SDCacheCostForImage(diskImage);
                    [self.memCache setObject:diskImage forKey:key cost:cost];
                }
            }
            
            if (doneBlock) {
                if (options & SDImageCacheQueryDiskSync) {
                    doneBlock(diskImage, diskData, cacheType);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        doneBlock(diskImage, diskData, cacheType);
                    });
                }
            }
        }
    };
    
    if (options & SDImageCacheQueryDiskSync) {
        queryDiskBlock();
    } else {
        dispatch_async(self.ioQueue, queryDiskBlock);
    }
    
    return operation;
}

#pragma mark - Remove Ops
//异步的从内存和硬盘缓存移除图片。
- (void)removeImageForKey:(nullable NSString *)key withCompletion:(nullable SDWebImageNoParamsBlock)completion {
    [self removeImageForKey:key fromDisk:YES withCompletion:completion];
}
//从内存中异步的移除图片，可选的从硬盘异步的移除图片。
- (void)removeImageForKey:(nullable NSString *)key fromDisk:(BOOL)fromDisk withCompletion:(nullable SDWebImageNoParamsBlock)completion {
    if (key == nil) {
        return;
    }

    if (self.config.shouldCacheImagesInMemory) {
//        从内存q中删除图片
        [self.memCache removeObjectForKey:key];
    }

    if (fromDisk) {
        dispatch_async(self.ioQueue, ^{
//            从内存中删除
            [self.fileManager removeItemAtPath:[self defaultCachePathForKey:key] error:nil];
            
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion();
                });
            }
        });
    } else if (completion){
        completion();
    }
    
}

# pragma mark - Mem Cache settings

- (void)setMaxMemoryCost:(NSUInteger)maxMemoryCost {
    self.memCache.totalCostLimit = maxMemoryCost;
}

- (NSUInteger)maxMemoryCost {
    return self.memCache.totalCostLimit;
}

- (NSUInteger)maxMemoryCountLimit {
    return self.memCache.countLimit;
}

- (void)setMaxMemoryCountLimit:(NSUInteger)maxCountLimit {
    self.memCache.countLimit = maxCountLimit;
}

#pragma mark - Cache clean Ops
//清理所有内容中的缓存图片,只是删除缓存，硬盘上的没有删除
- (void)clearMemory {
    [self.memCache removeAllObjects];
}
//异步清除所有硬盘缓存的图片。没有块方法则立即返回
- (void)clearDiskOnCompletion:(nullable SDWebImageNoParamsBlock)completion {
    dispatch_async(self.ioQueue, ^{
        [self.fileManager removeItemAtPath:self.diskCachePath error:nil];
//        根据路径删除之后，又根据路径创建相同的文件夹
        [self.fileManager createDirectoryAtPath:self.diskCachePath
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:NULL];

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion();
            });
        }
    });
}

- (void)deleteOldFiles {
    [self deleteOldFilesWithCompletionBlock:nil];
}
//异步从硬盘移除所有已过期的图片缓存。没有块方法则直接返回。
- (void)deleteOldFilesWithCompletionBlock:(nullable SDWebImageNoParamsBlock)completionBlock {
    dispatch_async(self.ioQueue, ^{
        NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];

//         Compute content date key to be used for tests
//        获取修改日期
        NSURLResourceKey cacheContentDateKey = NSURLContentModificationDateKey;
        switch (self.config.diskCacheExpireType) {
            case SDImageCacheConfigExpireTypeAccessDate:
//                图片的最后访问时间
                cacheContentDateKey = NSURLContentAccessDateKey;
                break;

            case SDImageCacheConfigExpireTypeModificationDate:
//                图片的最后修改时间
                cacheContentDateKey = NSURLContentModificationDateKey;
                break;

            default:
                break;
        }
        //NSURLIsDirectoryKey:  稍后允许你判断遍历到的URL所指对象是否是目录.
        //NSURLTotalFileAllocatedSizeKey : 文件总的分配大小
        NSArray<NSString *> *resourceKeys = @[NSURLIsDirectoryKey, cacheContentDateKey, NSURLTotalFileAllocatedSizeKey];
        //NSDirectoryEnumerationSkipsHiddenFiles : 过滤隐藏文件
        // This enumerator prefetches useful properties for our cache files.
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:resourceKeys
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];
       //根据配置的最大缓存时间，获取超时时间
        NSDate *expirationDate = [NSDate dateWithTimeIntervalSinceNow:-self.config.maxCacheAge];
        NSMutableDictionary<NSURL *, NSDictionary<NSString *, id> *> *cacheFiles = [NSMutableDictionary dictionary];
        NSUInteger currentCacheSize = 0;

        // Enumerate all of the files in the cache directory.  This loop has two purposes:
        //
        //  1. Removing files that are older than the expiration date.
        //  2. Storing file attributes for the size-based cleanup pass.
        NSMutableArray<NSURL *> *urlsToDelete = [[NSMutableArray alloc] init];
        for (NSURL *fileURL in fileEnumerator) {
            NSError *error;
//        resourceValues：   包含每一项指向的文件的属性
            NSDictionary<NSString *, id> *resourceValues = [fileURL resourceValuesForKeys:resourceKeys error:&error];

            // Skip directories and errors.
            if (error || !resourceValues || [resourceValues[NSURLIsDirectoryKey] boolValue]) {
                continue;
            }

            // Remove files that are older than the expiration date;
//            修改时间
            NSDate *modifiedDate = resourceValues[cacheContentDateKey];
            //            laterDate: 会返回较晚的时间，等于失效时间，就加到 urlsToDelete 数组里
            if ([[modifiedDate laterDate:expirationDate] isEqualToDate:expirationDate]) {
                [urlsToDelete addObject:fileURL];
                continue;
            }
            
            // Store a reference to this file and account for its total size.
            NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
            // 没有过期的，就记录下总缓存大小
            currentCacheSize += totalAllocatedSize.unsignedIntegerValue;
            cacheFiles[fileURL] = resourceValues;
        }
        
//        删除上个循环中获取到的过期的文件
        for (NSURL *fileURL in urlsToDelete) {
            [self.fileManager removeItemAtURL:fileURL error:nil];
        }

        // If our remaining disk cache exceeds a configured maximum size, perform a second
        // size-based cleanup pass.  We delete the oldest files first.
        if (self.config.maxCacheSize > 0 && currentCacheSize > self.config.maxCacheSize) {
        //   如果超过缓存最大值
            // Target half of our maximum cache size for this cleanup pass.
            const NSUInteger desiredCacheSize = self.config.maxCacheSize / 2;

            // Sort the remaining cache files by their last modification time (oldest first).
//按剩余的缓存文件的最后修改时间（最早的）进行排序。cacheFiles 已经过滤掉了过期的
            NSArray<NSURL *> *sortedFiles = [cacheFiles keysSortedByValueWithOptions:NSSortConcurrent
                                                                     usingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                         return [obj1[NSURLContentModificationDateKey] compare:obj2[NSURLContentModificationDateKey]];
                                                                     }];

            // Delete files until we fall below our desired cache size.
//            删除文件，直到我们低于所需的缓存大小
            for (NSURL *fileURL in sortedFiles) {
                if ([self.fileManager removeItemAtURL:fileURL error:nil]) {
//                  删除一个，重新计算下 currentCacheSize ，判断一下是否小于 最大缓存的一半
                    NSDictionary<NSString *, id> *resourceValues = cacheFiles[fileURL];
                    NSNumber *totalAllocatedSize = resourceValues[NSURLTotalFileAllocatedSizeKey];
                    currentCacheSize -= totalAllocatedSize.unsignedIntegerValue;

                    if (currentCacheSize < desiredCacheSize) {
                        break;
                    }
                }
            }
        }
        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completionBlock();
            });
        }
    });
}

#if SD_UIKIT
- (void)backgroundDeleteOldFiles {
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    UIApplication *application = [UIApplication performSelector:@selector(sharedApplication)];
    __block UIBackgroundTaskIdentifier bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];

    // Start the long-running task and return immediately.
    [self deleteOldFilesWithCompletionBlock:^{
        [application endBackgroundTask:bgTask];
        bgTask = UIBackgroundTaskInvalid;
    }];
}
#endif

#pragma mark - Cache Info
//获取被硬盘缓存使用的大小
- (NSUInteger)getSize {
    __block NSUInteger size = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
        for (NSString *fileName in fileEnumerator) {
            NSString *filePath = [self.diskCachePath stringByAppendingPathComponent:fileName];
            NSDictionary<NSString *, id> *attrs = [self.fileManager attributesOfItemAtPath:filePath error:nil];
            size += [attrs fileSize];
        }
    });
    return size;
}
//在硬盘缓存中获取图片的数量
- (NSUInteger)getDiskCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.ioQueue, ^{
        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtPath:self.diskCachePath];
        count = fileEnumerator.allObjects.count;
    });
    return count;
}
////异步计算硬盘缓存大小。
- (void)calculateSizeWithCompletionBlock:(nullable SDWebImageCalculateSizeBlock)completionBlock {
    NSURL *diskCacheURL = [NSURL fileURLWithPath:self.diskCachePath isDirectory:YES];
//   ioQueue 是串行队列，异步，会创建一个新线程，但因为是串行，所以不会出现读写问题
    dispatch_async(self.ioQueue, ^{
        NSUInteger fileCount = 0;
        NSUInteger totalSize = 0;

        NSDirectoryEnumerator *fileEnumerator = [self.fileManager enumeratorAtURL:diskCacheURL
                                                   includingPropertiesForKeys:@[NSFileSize]
                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                 errorHandler:NULL];

        for (NSURL *fileURL in fileEnumerator) {
            NSNumber *fileSize;
            [fileURL getResourceValue:&fileSize forKey:NSURLFileSizeKey error:NULL];
            totalSize += fileSize.unsignedIntegerValue;
            fileCount += 1;
        }

        if (completionBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
//                回调文件个数，和总大小
                completionBlock(fileCount, totalSize);
            });
        }
    });
}

@end

