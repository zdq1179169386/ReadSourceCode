/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageDownloaderOperation.h"
#import "SDWebImageManager.h"
#import "NSImage+WebCache.h"
#import "SDWebImageCodersManager.h"

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);

// iOS 8 Foundation.framework extern these symbol but the define is in CFNetwork.framework. We just fix this without import CFNetwork.framework
#if (__IPHONE_OS_VERSION_MIN_REQUIRED && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_9_0)
const float NSURLSessionTaskPriorityHigh = 0.75;
const float NSURLSessionTaskPriorityDefault = 0.5;
const float NSURLSessionTaskPriorityLow = 0.25;
#endif
//任务开始
NSString *const SDWebImageDownloadStartNotification = @"SDWebImageDownloadStartNotification";
//接收到数据
NSString *const SDWebImageDownloadReceiveResponseNotification = @"SDWebImageDownloadReceiveResponseNotification";
//暂停
NSString *const SDWebImageDownloadStopNotification = @"SDWebImageDownloadStopNotification";
//完成
NSString *const SDWebImageDownloadFinishNotification = @"SDWebImageDownloadFinishNotification";

static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kCompletedCallbackKey = @"completed";

typedef NSMutableDictionary<NSString *, id> SDCallbacksDictionary;

@interface SDWebImageDownloaderOperation ()
//存储的是当前request 下载的 进度的 progressBlock 和完成的 completedBlock。
@property (strong, nonatomic, nonnull) NSMutableArray<SDCallbacksDictionary *> *callbackBlocks;
//当前线程是否正在执行
@property (assign, nonatomic, getter = isExecuting) BOOL executing;
//当前线程是否完成
@property (assign, nonatomic, getter = isFinished) BOOL finished;
//存储图片数据
@property (strong, nonatomic, nullable) NSMutableData *imageData;
@property (copy, nonatomic, nullable) NSData *cachedData; // for `SDWebImageDownloaderIgnoreCachedResponse`

// This is weak because it is injected by whoever manages this session. If this gets nil-ed out, we won't be able to run
// the task associated with this operation
@property (weak, nonatomic, nullable) NSURLSession *unownedSession;
// This is set if we're using not using an injected NSURLSession. We're responsible of invalidating this one
@property (strong, nonatomic, nullable) NSURLSession *ownedSession;

@property (strong, nonatomic, readwrite, nullable) NSURLSessionTask *dataTask;
//信号量
@property (strong, nonatomic, nonnull) dispatch_semaphore_t callbacksLock; // a lock to keep the access to `callbackBlocks` thread-safe

//串行队列
@property (strong, nonatomic, nonnull) dispatch_queue_t coderQueue; // the queue to do image decoding
#if SD_UIKIT
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;
#endif

@property (strong, nonatomic, nullable) id<SDWebImageProgressiveCoder> progressiveCoder;

@end

@implementation SDWebImageDownloaderOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (nonnull instancetype)init {
    return [self initWithRequest:nil inSession:nil options:0];
}

- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(SDWebImageDownloaderOptions)options {
    if ((self = [super init])) {
        _request = [request copy];
        _shouldDecompressImages = YES;
        _options = options;
        _callbackBlocks = [NSMutableArray new];
        _executing = NO;
        _finished = NO;
        _expectedSize = 0;
        _unownedSession = session;
        _callbacksLock = dispatch_semaphore_create(1);
        _coderQueue = dispatch_queue_create("com.hackemist.SDWebImageDownloaderOperationCoderQueue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

/*
 添加进度和完成的处理。返回一个能够传递cancel:去取消回调集合的token。
 注意：这个进度块在后台队列中执行。
 注意：完成块当成功时在主线程中执行。如果发生错误，有一次在后台队列执行的机会。
 callbacks：存储的是当前request 下载的 进度的 progressBlock 和完成的 completedBlock。
 */
- (nullable id)addHandlersForProgress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                            completed:(nullable SDWebImageDownloaderCompletedBlock)completedBlock {
    SDCallbacksDictionary *callbacks = [NSMutableDictionary new];
    if (progressBlock) callbacks[kProgressCallbackKey] = [progressBlock copy];
    if (completedBlock) callbacks[kCompletedCallbackKey] = [completedBlock copy];
    LOCK(self.callbacksLock);
    [self.callbackBlocks addObject:callbacks];
    UNLOCK(self.callbacksLock);
    return callbacks;
}

//根据key取出所有符合key的block
- (nullable NSArray<id> *)callbacksForKey:(NSString *)key {
    LOCK(self.callbacksLock);
//    如果key 是 kProgressCallbackKey ，那么 callbacks 就是所有进度block 的数组，如果 key 是 kCompletedCallbackKey，那么 callbacks 就是 所有完成block 的数组
    NSMutableArray<id> *callbacks = [[self.callbackBlocks valueForKey:key] mutableCopy];
    UNLOCK(self.callbacksLock);
    // We need to remove [NSNull null] because there might not always be a progress block for each callback
    [callbacks removeObjectIdenticalTo:[NSNull null]];
    return [callbacks copy]; // strip mutability here
}
//取消某一回调,token 和addHandlersForProgress:completed:方法的返回值对应
// 但是 addHandlersForProgress 方法返回的是一个装有进度block 和完成block 的字典啊
- (BOOL)cancel:(nullable id)token {
    BOOL shouldCancel = NO;
    LOCK(self.callbacksLock);
//     删除数组中指定元素,根据对象的地址判断
    [self.callbackBlocks removeObjectIdenticalTo:token];
    if (self.callbackBlocks.count == 0) {
        shouldCancel = YES;
    }
    UNLOCK(self.callbacksLock);
    if (shouldCancel) {
        [self cancel];
    }
    return shouldCancel;
}
/*
 并不是调用了cancel就一定取消了，如果NSOperation没有执行，那么就会取消，如果执行了，只会将isCancelled设置为YES。所以，在我们的操作中，我们应该在每个操作开始前，或者在每个有意义的实际操作完成后，先检查下这个属性是不是已经设置为YES。如果是YES，则后面操作都可以不用再执行了。
 */
- (void)start {
    @synchronized (self) {
        if (self.isCancelled) {
            self.finished = YES;
            [self reset];
            return;
        }

#if SD_UIKIT
        Class UIApplicationClass = NSClassFromString(@"UIApplication");
        BOOL hasApplication = UIApplicationClass && [UIApplicationClass respondsToSelector:@selector(sharedApplication)];
        if (hasApplication && [self shouldContinueWhenAppEntersBackground]) {
            //如果用户设置了Background模式，则设置一个backgroundTask
            __weak __typeof__ (self) wself = self;
            UIApplication * app = [UIApplicationClass performSelector:@selector(sharedApplication)];
            self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
                __strong __typeof (wself) sself = wself;

                if (sself) {
                    [sself cancel];

                    [app endBackgroundTask:sself.backgroundTaskId];
                    sself.backgroundTaskId = UIBackgroundTaskInvalid;
                }
            }];
        }
#endif
        NSURLSession *session = self.unownedSession;
        if (!session) {
            //如果SDWebImageDownloader传入的session是nil，则自己手动初始化一个
            NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
            sessionConfig.timeoutIntervalForRequest = 15;
            
            /**
             *  Create the session for this task
             *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
             *  method calls and completion handler calls.
             */
            session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                    delegate:self
                                               delegateQueue:nil];
            self.ownedSession = session;
        }
        
        if (self.options & SDWebImageDownloaderIgnoreCachedResponse) {
            // Grab the cached data for later check
            NSURLCache *URLCache = session.configuration.URLCache;
            if (!URLCache) {
                URLCache = [NSURLCache sharedURLCache];
            }
            NSCachedURLResponse *cachedResponse;
            // NSURLCache's `cachedResponseForRequest:` is not thread-safe, see https://developer.apple.com/documentation/foundation/nsurlcache#2317483
//            cachedResponseForRequest ：不是线程安全的
//            @synchronized 的作用是创建一个互斥锁，保证此时没有其它线程对URLCache 对象进行修改
            @synchronized (URLCache) {
                cachedResponse = [URLCache cachedResponseForRequest:self.request];
            }
            if (cachedResponse) {
                self.cachedData = cachedResponse.data;
            }
        }
        
        self.dataTask = [session dataTaskWithRequest:self.request];
        self.executing = YES;
    }

    if (self.dataTask) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
//        设置优先级
        if ([self.dataTask respondsToSelector:@selector(setPriority:)]) {
            if (self.options & SDWebImageDownloaderHighPriority) {
                self.dataTask.priority = NSURLSessionTaskPriorityHigh;
            } else if (self.options & SDWebImageDownloaderLowPriority) {
                self.dataTask.priority = NSURLSessionTaskPriorityLow;
            }
        }
#pragma clang diagnostic pop
//        执行当前 task
        [self.dataTask resume];
        for (SDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(0, NSURLResponseUnknownLength, self.request.URL);
        }
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStartNotification object:weakSelf];
        });
    } else {
        //task 初始化失败，立刻执行回调的block
        [self callCompletionBlocksWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnknown userInfo:@{NSLocalizedDescriptionKey : @"Task can't be initialized"}]];
        [self done];
        return;
    }

#if SD_UIKIT
//    后台任务
    Class UIApplicationClass = NSClassFromString(@"UIApplication");
    if(!UIApplicationClass || ![UIApplicationClass respondsToSelector:@selector(sharedApplication)]) {
        return;
    }
    if (self.backgroundTaskId != UIBackgroundTaskInvalid) {
        UIApplication * app = [UIApplication performSelector:@selector(sharedApplication)];
        [app endBackgroundTask:self.backgroundTaskId];
        self.backgroundTaskId = UIBackgroundTaskInvalid;
    }
#endif
}
// SDWebImageOperation 协议
- (void)cancel {
    @synchronized (self) {
        [self cancelInternal];
    }
}
//内部取消
- (void)cancelInternal {
    if (self.isFinished) return;
    [super cancel];

    if (self.dataTask) {
//      取消 task
        [self.dataTask cancel];
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStopNotification object:weakSelf];
        });

        // As we cancelled the task, its callback won't be called and thus won't
        // maintain the isFinished and isExecuting flags.
//        变更状态
        if (self.isExecuting) self.executing = NO;
        if (!self.isFinished) self.finished = YES;
    }

    [self reset];
}
//下载完成
- (void)done {
    self.finished = YES;
    self.executing = NO;
    [self reset];
}
// 如果任务已经被设置为取消了，那么就无需开启下载任务了，并进行重置
- (void)reset {
    LOCK(self.callbacksLock);
    [self.callbackBlocks removeAllObjects];
    UNLOCK(self.callbacksLock);
    self.dataTask = nil;
    
    if (self.ownedSession) {
//    调用了 invalidateAndCancel 会先执行 SDWebImageDownloader 中的 didCompleteWithError：方法，然后它会做个轮询，找到对应的operation 转发，传递到本类中 didCompleteWithError ：的方法中
        [self.ownedSession invalidateAndCancel];
        self.ownedSession = nil;
    }
}
// 需要手动触发_finished的KVO，这个是自定义`NSOperation`必须实现的
- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}
//需要手动触发_executing的KVO，这个是自定义`NSOperation`必须实现的
- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}
/*
 https://www.jianshu.com/p/ebb3e42049fd
 该方法现在已经由isAsynchronous方法代替，并且 NSOperationQueue 也已经忽略这个方法的值。
 isAsynchronous: 该方法默认返回 NO ，表示非并发执行。并发执行需要自定义并且返回 YES。后面会根据这个返回值来决定是否并发。
 */
- (BOOL)isConcurrent {
    return YES;
}

#pragma mark NSURLSessionDataDelegate
/*
这里所有的代理方法，都会由 SDWebImageDownloader 做一次转发 */
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSURLSessionResponseDisposition disposition = NSURLSessionResponseAllow;
     //期望的总长度
    NSInteger expected = (NSInteger)response.expectedContentLength;
    expected = expected > 0 ? expected : 0;
    self.expectedSize = expected;
    self.response = response;
    NSInteger statusCode = [response respondsToSelector:@selector(statusCode)] ? ((NSHTTPURLResponse *)response).statusCode : 200;
    BOOL valid = statusCode < 400;
    //'304 Not Modified' is an exceptional one. It should be treated as cancelled if no cache data
    //URLSession current behavior will return 200 status code when the server respond 304 and URLCache hit. But this is not a standard behavior and we just add a check
//    http 状态码 304 ，表示内容未修改，具体看这篇文章，https://blog.csdn.net/huwei2003/article/details/70139062
    
    if (statusCode == 304 && !self.cachedData) {
//        未修改时，cachedData 不应该有数据吗
        valid = NO;
    }
    
    if (valid) {
        for (SDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
            progressBlock(0, expected, self.request.URL);
        }
    } else {
        // Status code invalid and marked as cancelled. Do not call `[self.dataTask cancel]` which may mass up URLSession life cycle
        //如果返回304表示图片没有变化，在这种情况下，我们只需要取消operation并且返回缓存的图片就可以了
        disposition = NSURLSessionResponseCancel;
    }
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadReceiveResponseNotification object:weakSelf];
    });
    
    if (completionHandler) {
        completionHandler(disposition);
    }
}
//会被多次调用，获取图片数据
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (!self.imageData) {
        self.imageData = [[NSMutableData alloc] initWithCapacity:self.expectedSize];
    }
    [self.imageData appendData:data];

    // 当options 设置为 SDWebImageProgressiveDownload  才会进入到这里 ，渐进式解码
    if ((self.options & SDWebImageDownloaderProgressiveDownload) && self.expectedSize > 0) {
        // Get the image data
        __block NSData *imageData = [self.imageData copy];
        // Get the total bytes downloaded
        //获取已经下载的数据长度
        const NSInteger totalSize = imageData.length;
        // Get the finish status
        BOOL finished = (totalSize >= self.expectedSize);
        
        if (!self.progressiveCoder) {
            // We need to create a new instance for progressive decoding to avoid conflicts
//            我们需要为渐进式解码创建一个新实例以避免冲突
            for (id<SDWebImageCoder>coder in [SDWebImageCodersManager sharedInstance].coders) {
                if ([coder conformsToProtocol:@protocol(SDWebImageProgressiveCoder)] &&
                    [((id<SDWebImageProgressiveCoder>)coder) canIncrementallyDecodeFromData:imageData]) {
                    self.progressiveCoder = [[[coder class] alloc] init];
                    break;
                }
            }
        }
//     self.coderQueue： 用来解码的串行队列
        // progressive decode the image in coder queue
        dispatch_async(self.coderQueue, ^{
            UIImage *image = [self.progressiveCoder incrementallyDecodedImageWithData:imageData finished:finished];
            if (image) {
                NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:self.request.URL];
                image = [self scaledImageForKey:key image:image];
                if (self.shouldDecompressImages) {
                    image = [[SDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&imageData options:@{SDWebImageCoderScaleDownLargeImagesKey: @(NO)}];
                }
                
                // We do not keep the progressive decoding image even when `finished`=YES. Because they are for view rendering but not take full function from downloader options. And some coders implementation may not keep consistent between progressive decoding and normal decoding.
                
                [self callCompletionBlocksWithImage:image imageData:nil error:nil finished:NO];
            }
        });
    }

    for (SDWebImageDownloaderProgressBlock progressBlock in [self callbacksForKey:kProgressCallbackKey]) {
//      回调进度的block
        progressBlock(self.imageData.length, self.expectedSize, self.request.URL);
    }
}
//用于响应缓存设置，如果把回调的参数设置为nil，那么就不会缓存响应
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    //根据request的选项，决定是否缓存NSCachedURLResponse
    NSCachedURLResponse *cachedResponse = proposedResponse;

    if (!(self.options & SDWebImageDownloaderUseNSURLCache)) {
        // Prevents caching of responses
        cachedResponse = nil;
    }
    if (completionHandler) {
        completionHandler(cachedResponse);
    }
}

#pragma mark NSURLSessionTaskDelegate
//网络请求加载完成，在这里处理获得的数据
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    @synchronized(self) {
        self.dataTask = nil;
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadStopNotification object:weakSelf];
            if (!error) {
//                发送图片下载完成的通知
                [[NSNotificationCenter defaultCenter] postNotificationName:SDWebImageDownloadFinishNotification object:weakSelf];
            }
        });
    }
    
    // make sure to call `[self done]` to mark operation as finished
    if (error) {
        [self callCompletionBlocksWithError:error];
        [self done];
    } else {
        if ([self callbacksForKey:kCompletedCallbackKey].count > 0) {
            /**
             *  If you specified to use `NSURLCache`, then the response you get here is what you need.
             */
//            当你使用 NSURLCache 时，会执行这块逻辑
            __block NSData *imageData = [self.imageData copy];
            if (imageData) {
                /**  if you specified to only use cached data via `SDWebImageDownloaderIgnoreCachedResponse`,
                 *  then we should check if the cached data is equal to image data
                 */
//              当使用 SDWebImageDownloaderIgnoreCachedResponse，那么我们应该检查缓存的数据是否等于图像数据
                if (self.options & SDWebImageDownloaderIgnoreCachedResponse && [self.cachedData isEqualToData:imageData]) {
                    // call completion block with nil
                    [self callCompletionBlocksWithImage:nil imageData:nil error:nil finished:YES];
                    [self done];
                } else {
                    // decode the image in coder queue
                    dispatch_async(self.coderQueue, ^{
                        UIImage *image = [[SDWebImageCodersManager sharedInstance] decodedImageWithData:imageData];
                        //获取url对应的缓存Key
                        NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:self.request.URL];
                        image = [self scaledImageForKey:key image:image];
                        
                        BOOL shouldDecode = YES;
                        // Do not force decoding animated GIFs and WebPs
                        if (image.images) {
                            shouldDecode = NO;
                        } else {
#ifdef SD_WEBP
                            SDImageFormat imageFormat = [NSData sd_imageFormatForImageData:imageData];
                            if (imageFormat == SDImageFormatWebP) {
                                shouldDecode = NO;
                            }
#endif
                        }
                        //是否解码图片数据
                        if (shouldDecode) {
                            if (self.shouldDecompressImages) {
                                //如果设置了SDWebImageDownloaderScaleDownLargeImages，则返回处理过的图片
                                // (width = 828, height = 466)
                                BOOL shouldScaleDown = self.options & SDWebImageDownloaderScaleDownLargeImages;
                                image = [[SDWebImageCodersManager sharedInstance] decompressedImageWithImage:image data:&imageData options:@{SDWebImageCoderScaleDownLargeImagesKey: @(shouldScaleDown)}];
                            }
                        }
                        CGSize imageSize = image.size;
                        if (imageSize.width == 0 || imageSize.height == 0) {
                            [self callCompletionBlocksWithError:[NSError errorWithDomain:SDWebImageErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Downloaded image has 0 pixels"}]];
                        } else {
                            [self callCompletionBlocksWithImage:image imageData:imageData error:nil finished:YES];
                        }
                        [self done];
                    });
                }
            } else {
                [self callCompletionBlocksWithError:[NSError errorWithDomain:SDWebImageErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"Image data is nil"}]];
                [self done];
            }
        } else {
            [self done];
        }
    }
}
//验证HTTPS的证书
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
//    忽略证书(默认的处理方式)
    NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
    __block NSURLCredential *credential = nil;
    //使用可信任证书机构的证书
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        if (!(self.options & SDWebImageDownloaderAllowInvalidSSLCertificates)) {
            //如果SDWebImageDownloaderAllowInvalidSSLCertificates属性设置了，则不验证SSL证书，直接信任
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        } else {
            credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
//            使用证书
            disposition = NSURLSessionAuthChallengeUseCredential;
        }
    } else {
        if (challenge.previousFailureCount == 0) {
            //使用自己生成的证书
            if (self.credential) {
                credential = self.credential;
                disposition = NSURLSessionAuthChallengeUseCredential;
            } else {
//              忽略书证, 并取消这次请求
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        } else {
            disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
        }
    }
    //验证证书
    if (completionHandler) {
        completionHandler(disposition, credential);
    }
}

#pragma mark Helper methods
- (nullable UIImage *)scaledImageForKey:(nullable NSString *)key image:(nullable UIImage *)image {
    return SDScaledImageForKey(key, image);
}

- (BOOL)shouldContinueWhenAppEntersBackground {
    return self.options & SDWebImageDownloaderContinueInBackground;
}
//回调的block
- (void)callCompletionBlocksWithError:(nullable NSError *)error {
    [self callCompletionBlocksWithImage:nil imageData:nil error:error finished:YES];
}

- (void)callCompletionBlocksWithImage:(nullable UIImage *)image
                            imageData:(nullable NSData *)imageData
                                error:(nullable NSError *)error
                             finished:(BOOL)finished {
    //获取key对应的回调Block数组
    NSArray<id> *completionBlocks = [self callbacksForKey:kCompletedCallbackKey];
//    dispatch_queue_async_safe(dispatch_get_main_queue(), block)，同步+主线程，因为回调的block 可能会操作 UI，所以都是放在主线程
//    afn 完成的block 好像也是这样
    dispatch_main_async_safe(^{
        for (SDWebImageDownloaderCompletedBlock completedBlock in completionBlocks) {
            completedBlock(image, imageData, error, finished);
        }
    });
}

@end
