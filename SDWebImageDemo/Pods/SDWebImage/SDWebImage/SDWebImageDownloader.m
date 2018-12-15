/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import "SDWebImageDownloader.h"
#import "SDWebImageDownloaderOperation.h"

#define LOCK(lock) dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
#define UNLOCK(lock) dispatch_semaphore_signal(lock);

@interface SDWebImageDownloadToken ()

@property (nonatomic, weak, nullable) NSOperation<SDWebImageDownloaderOperationInterface> *downloadOperation;

@end

@implementation SDWebImageDownloadToken

- (void)cancel {
    if (self.downloadOperation) {
        SDWebImageDownloadToken *cancelToken = self.downloadOperationCancelToken;
        if (cancelToken) {
            [self.downloadOperation cancel:cancelToken];
        }
    }
}

@end


@interface SDWebImageDownloader () <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
//!<所有的下载图片的Operation都加入NSOperationQueue中
@property (strong, nonatomic, nonnull) NSOperationQueue *downloadQueue;
//!<最后一个添加的Operation
@property (weak, nonatomic, nullable) NSOperation *lastAddedOperation;
//!<自定义的NSOperation子类
@property (assign, nonatomic, nullable) Class operationClass;
//!<用于记录url和它对应的SDWebImageDownloaderOperation对象
@property (strong, nonatomic, nonnull) NSMutableDictionary<NSURL *, SDWebImageDownloaderOperation *> *URLOperations;
//!<请求头域字典
@property (strong, nonatomic, nullable) SDHTTPHeadersMutableDictionary *HTTPHeaders;
// 锁住 操作 URLOperations，保证线程安全
@property (strong, nonatomic, nonnull) dispatch_semaphore_t operationsLock; // a lock to keep the access to `URLOperations` thread-safe
// 锁住 HTTPHeaders，保证线程安全
@property (strong, nonatomic, nonnull) dispatch_semaphore_t headersLock; // a lock to keep the access to `HTTPHeaders` thread-safe

// The session in which data tasks will run
//!<通过这个`NSURLSession`创建请求
@property (strong, nonatomic) NSURLSession *session;

@end

@implementation SDWebImageDownloader
/*
 该方法是为了给图片下载绑定一个SDNetworkActivityIndicator，只有当这个SDNetworkActivityIndicator文件存在的情况下才会执行，目的就是当下载图片时，状态栏会转小菊花。
 */
+ (void)initialize {
    // Bind SDNetworkActivityIndicator if available (download it here: http://github.com/rs/SDNetworkActivityIndicator )
    // To use it, just add #import "SDNetworkActivityIndicator.h" in addition to the SDWebImage import
    if (NSClassFromString(@"SDNetworkActivityIndicator")) {

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        id activityIndicator = [NSClassFromString(@"SDNetworkActivityIndicator") performSelector:NSSelectorFromString(@"sharedActivityIndicator")];
#pragma clang diagnostic pop

        // Remove observer in case it was previously added.
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator name:SDWebImageDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:activityIndicator name:SDWebImageDownloadStopNotification object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator
                                                 selector:NSSelectorFromString(@"startActivity")
                                                     name:SDWebImageDownloadStartNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:activityIndicator
                                                 selector:NSSelectorFromString(@"stopActivity")
                                                     name:SDWebImageDownloadStopNotification object:nil];
    }
}

+ (nonnull instancetype)sharedDownloader {
    static dispatch_once_t once;
    static id instance;
    dispatch_once(&once, ^{
        instance = [self new];
    });
    return instance;
}

- (nonnull instancetype)init {
    return [self initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
}
//根据指定的会话配置创建一个下载器实例。注意：timeoutIntervalForRequest将会被重写。
- (nonnull instancetype)initWithSessionConfiguration:(nullable NSURLSessionConfiguration *)sessionConfiguration {
    if ((self = [super init])) {
//  SDWebImageDownloaderOperation ：自定义线程类 ，每发起一个请求，就会创建一个线程，这里会用属性记录类名记录下，方便其他地方使用
        _operationClass = [SDWebImageDownloaderOperation class];
        _shouldDecompressImages = YES;
//        先进先出
        _executionOrder = SDWebImageDownloaderFIFOExecutionOrder;
        _downloadQueue = [NSOperationQueue new];
//        最大并发数，最大支持下载6张图片
        _downloadQueue.maxConcurrentOperationCount = 6;
        _downloadQueue.name = @"com.hackemist.SDWebImageDownloader";
        _URLOperations = [NSMutableDictionary new];
#ifdef SD_WEBP
/*
 我们看看image/webp,image/*;q=0.8是什么意思，image/webp是webp格式的图片，q=0.8指的是权重系数为0.8，q的取值范围是0 - 1， 默认值为1，q作用于它前边分号;前边的内容。在这里，image/webp,image/*;q=0.8表示优先接受image/webp，其次接受image/*的图片。
 */
        _HTTPHeaders = [@{@"Accept": @"image/webp,image/*;q=0.8"} mutableCopy];
#else
        _HTTPHeaders = [@{@"Accept": @"image/*;q=0.8"} mutableCopy];
#endif
        _operationsLock = dispatch_semaphore_create(1);
        _headersLock = dispatch_semaphore_create(1);
        _downloadTimeout = 15.0;

        [self createNewSessionWithConfiguration:sessionConfiguration];
    }
    return self;
}
/*
 强制SDWebImageDownloader创建和使用一个根据提供的配置初始化的新NSURLSession。注意：所有在队列中已经存在的下载操作都会被取消。注意：timeoutIntervalForRequest将会被重写。
 */
- (void)createNewSessionWithConfiguration:(NSURLSessionConfiguration *)sessionConfiguration {
    [self cancelAllDownloads];

    if (self.session) {
        [self.session invalidateAndCancel];
    }

    sessionConfiguration.timeoutIntervalForRequest = self.downloadTimeout;

    /**
     *  Create the session for this task
     *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
     *  method calls and completion handler calls.
     */
    //我们将nil作为委托队列发送，以便会话创建一个串行操作队列，用于执行所有委托方法调用和完成处理程序调用。
    self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration
                                                 delegate:self
                                            delegateQueue:nil];
}

- (void)invalidateSessionAndCancel:(BOOL)cancelPendingOperations {
    if (self == [SDWebImageDownloader sharedDownloader]) {
        return;
    }
    if (cancelPendingOperations) {
        [self.session invalidateAndCancel];
    } else {
        [self.session finishTasksAndInvalidate];
    }
}

- (void)dealloc {
    [self.session invalidateAndCancel];
    self.session = nil;

    [self.downloadQueue cancelAllOperations];
}
// 设置请求头域
- (void)setValue:(nullable NSString *)value forHTTPHeaderField:(nullable NSString *)field {
    LOCK(self.headersLock);
    if (value) {
        self.HTTPHeaders[field] = value;
    } else {
        [self.HTTPHeaders removeObjectForKey:field];
    }
    UNLOCK(self.headersLock);
}
// 获取请求头域的值
- (nullable NSString *)valueForHTTPHeaderField:(nullable NSString *)field {
    if (!field) {
        return nil;
    }
    return [[self allHTTPHeaderFields] objectForKey:field];
}

- (nonnull SDHTTPHeadersDictionary *)allHTTPHeaderFields {
//  信号量，返回过滤的请求头
    LOCK(self.headersLock);
    SDHTTPHeadersDictionary *allHTTPHeaderFields = [self.HTTPHeaders copy];
    UNLOCK(self.headersLock);
    return allHTTPHeaderFields;
}
//设置最大并发数
- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads {
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}
//获取当前并行下载数量
- (NSUInteger)currentDownloadCount {
    return _downloadQueue.operationCount;
}
//获取最大并发数
- (NSInteger)maxConcurrentDownloads {
    return _downloadQueue.maxConcurrentOperationCount;
}

- (NSURLSessionConfiguration *)sessionConfiguration {
    return self.session.configuration;
}
// 设置一个`SDWebImageDownloaderOperation`的子类作为`NSOperation`来构建request来下载一张图片
- (void)setOperationClass:(nullable Class)operationClass {
    if (operationClass && [operationClass isSubclassOfClass:[NSOperation class]] && [operationClass conformsToProtocol:@protocol(SDWebImageDownloaderOperationInterface)]) {
        _operationClass = operationClass;
    } else {
        _operationClass = [SDWebImageDownloaderOperation class];
    }
}
/*
 根据提供的URL创建一个SDWebImageDownloader异步下载实例。
 代理在图片下载完成或发生一个错误后被执行。
 注意：进度块在后台队列中执行。
 */
- (nullable SDWebImageDownloadToken *)downloadImageWithURL:(nullable NSURL *)url
                                                   options:(SDWebImageDownloaderOptions)options
                                                  progress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                                                 completed:(nullable SDWebImageDownloaderCompletedBlock)completedBlock {
    __weak SDWebImageDownloader *wself = self;

    return [self addProgressCallback:progressBlock completedBlock:completedBlock forURL:url createCallback:^SDWebImageDownloaderOperation *{
        __strong __typeof (wself) sself = wself;
        NSTimeInterval timeoutInterval = sself.downloadTimeout;
        if (timeoutInterval == 0.0) {
            timeoutInterval = 15.0;
        }

        // In order to prevent from potential duplicate caching (NSURLCache + SDImageCache) we disable the cache for image requests if told otherwise
//      为了防止潜在的重复缓存（NSURLCache + SDImageCache），如果另有说明，我们会禁用图像请求的缓存
        NSURLRequestCachePolicy cachePolicy = options & SDWebImageDownloaderUseNSURLCache ? NSURLRequestUseProtocolCachePolicy : NSURLRequestReloadIgnoringLocalCacheData;
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                    cachePolicy:cachePolicy
                                                                timeoutInterval:timeoutInterval];
        
        request.HTTPShouldHandleCookies = (options & SDWebImageDownloaderHandleCookies);
//      保证在前一个请求没有返回的情况下，可以接着发送第二个请求
        request.HTTPShouldUsePipelining = YES;
        if (sself.headersFilter) {
//          设置请求头
//          每一request执行的时候，这个Block都会被执行。用于向http请求添加请求域
//          headersFilter  这个block 的实现，不知道在哪
           /*
            至少有这段实现的代码，不知道在哪
            sself.headersFilter = ^SDHTTPHeadersDictionary * _Nullable(NSURL * _Nullable url, SDHTTPHeadersDictionary * _Nullable headers) {
                  return @{};
            };
            */
            request.allHTTPHeaderFields = sself.headersFilter(url, [sself allHTTPHeaderFields]);
        }
        else {
            request.allHTTPHeaderFields = [sself allHTTPHeaderFields];
        }
//      根据请求和session 生成个线程，取消请求的时候，也是取消这个线程
        //        operationClass:可以自己设置个子类自己去实现下载图片的协议
        SDWebImageDownloaderOperation *operation = [[sself.operationClass alloc] initWithRequest:request inSession:sself.session options:options];
//
        operation.shouldDecompressImages = sself.shouldDecompressImages;
        
//        设置SSL证书
        if (sself.urlCredential) {
            operation.credential = sself.urlCredential;
        } else if (sself.username && sself.password) {
            operation.credential = [NSURLCredential credentialWithUser:sself.username password:sself.password persistence:NSURLCredentialPersistenceForSession];
        }
//        指定优先级
        if (options & SDWebImageDownloaderHighPriority) {
            operation.queuePriority = NSOperationQueuePriorityHigh;
        } else if (options & SDWebImageDownloaderLowPriority) {
            operation.queuePriority = NSOperationQueuePriorityLow;
        }
        //如果是LIFO这种模式，则需要手动指定operation之间的依赖关系
        if (sself.executionOrder == SDWebImageDownloaderLIFOExecutionOrder) {
            // Emulate LIFO execution order by systematically adding new operations as last operation's dependency
//     如果是LIFO，则让前面的operation依赖于最新添加的operation
            [sself.lastAddedOperation addDependency:operation];
            sself.lastAddedOperation = operation;
        }

        return operation;
    }];
}
//取消一个使用downloadImageWithURL:options:progress:completed:生成的在之前队列中的下载任务。
- (void)cancel:(nullable SDWebImageDownloadToken *)token {
    NSURL *url = token.url;
    if (!url) {
        return;
    }
    LOCK(self.operationsLock);
    SDWebImageDownloaderOperation *operation = [self.URLOperations objectForKey:url];
    if (operation) {
//        取消线程
        BOOL canceled = [operation cancel:token.downloadOperationCancelToken];
        if (canceled) {
//            取消成功了，再从字典中删除
            [self.URLOperations removeObjectForKey:url];
        }
    }
    UNLOCK(self.operationsLock);
}
//给下载过程添加进度
- (nullable SDWebImageDownloadToken *)addProgressCallback:(SDWebImageDownloaderProgressBlock)progressBlock
                                           completedBlock:(SDWebImageDownloaderCompletedBlock)completedBlock
                                                   forURL:(nullable NSURL *)url
                                           createCallback:(SDWebImageDownloaderOperation *(^)(void))createCallback {
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no image or data.
    if (url == nil) {
        if (completedBlock != nil) {
            completedBlock(nil, nil, nil, NO);
        }
        return nil;
    }
//    信号量，单线程访问
    LOCK(self.operationsLock);
//    一个从未下载过的url，operation 是空的，
    SDWebImageDownloaderOperation *operation = [self.URLOperations objectForKey:url];
    // There is a case that the operation may be marked as finished, but not been removed from `self.URLOperations`.
    if (!operation || operation.isFinished) {
//   这里调用 createCallback ，会调用上面 downloadImageWithURL 方法中的  [self addProgressCallback：的 createCallback 的实现，从而返回一个operation ，并且设置了ssl 证书，请求头，优先级
        operation = createCallback();
        __weak typeof(self) wself = self;
//        完成后的block
        operation.completionBlock = ^{
            __strong typeof(wself) sself = wself;
            if (!sself) {
                return;
            }
            LOCK(sself.operationsLock);
            [sself.URLOperations removeObjectForKey:url];
            UNLOCK(sself.operationsLock);
        };
        [self.URLOperations setObject:operation forKey:url];
        // Add operation to operation queue only after all configuration done according to Apple's doc.
        // `addOperation:` does not synchronously execute the `operation.completionBlock` so this will not cause deadlock.
        //把operation添加进入NSOperationQueue中，当operation添加到downloadQueue，会触发相应的start方法，开始下载。
        [self.downloadQueue addOperation:operation];
    }
    UNLOCK(self.operationsLock);
//    线程id，取消线程的时候就根据这个id，这个 downloadOperationCancelToken 实际上是一个装有进度block 和完成 block 的字典
    id downloadOperationCancelToken = [operation addHandlersForProgress:progressBlock completed:completedBlock];
    
    SDWebImageDownloadToken *token = [SDWebImageDownloadToken new];
    token.downloadOperation = operation;
    token.url = url;
    token.downloadOperationCancelToken = downloadOperationCancelToken;

    return token;
}
// 全部暂停/开始
- (void)setSuspended:(BOOL)suspended {
    self.downloadQueue.suspended = suspended;
}
//全部取消下载
- (void)cancelAllDownloads {
    [self.downloadQueue cancelAllOperations];
}

#pragma mark Helper methods
// 根据task 获取 task 正在执行的那个线程
- (SDWebImageDownloaderOperation *)operationWithTask:(NSURLSessionTask *)task {
    SDWebImageDownloaderOperation *returnOperation = nil;
    for (SDWebImageDownloaderOperation *operation in self.downloadQueue.operations) {
        if (operation.dataTask.taskIdentifier == task.taskIdentifier) {
            returnOperation = operation;
            break;
        }
    }
    return returnOperation;
}
/*
 在多张图片下载的时候，会先根据downloadUrl：方法，生成多个operation ，当 operation 加入到operationQueue 的时候，才会执行 operation 的start 方法，这时候才会根据request 生成 datatask ，调用 [datatask resume] 去执行这个下载请求。
 多个task 在执行的时候，根据 task 作为id 找到根据url 生成的那个operation， 将委托方法，传到对应的那个线程去执行
 */
#pragma mark NSURLSessionDataDelegate
//接收到服务器的响应 它默认会取消该请求
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {

    // Identify the operation that runs this task and pass it the delegate method
    SDWebImageDownloaderOperation *dataOperation = [self operationWithTask:dataTask];
    if ([dataOperation respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [dataOperation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionResponseAllow);
        }
    }
}
//接收到服务器返回的数据 调用多次
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {

    // Identify the operation that runs this task and pass it the delegate method
    SDWebImageDownloaderOperation *dataOperation = [self operationWithTask:dataTask];
    if ([dataOperation respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [dataOperation URLSession:session dataTask:dataTask didReceiveData:data];
    }
}
//缓存数据,这里可以使用系统默认的就行，这个是要将response缓存起来
- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {

    // Identify the operation that runs this task and pass it the delegate method
    SDWebImageDownloaderOperation *dataOperation = [self operationWithTask:dataTask];
    if ([dataOperation respondsToSelector:@selector(URLSession:dataTask:willCacheResponse:completionHandler:)]) {
        [dataOperation URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(proposedResponse);
        }
    }
}

#pragma mark NSURLSessionTaskDelegate
//会话失效
//通知URL会话该会话已失效。
//如果通过调用finishTasksAndInvalidate方法使会话失效，则会话将一直等待，直到会话中的最终任务完成或失败，然后再调用此委托方法。如果您调用invalidateAndCancel方法，
//会话将立即调用此委托方法。
//对于每一个完成的后台Task调用该Session的Delegate中的URLSession:downloadTask:didFinishDownloadingToURL:（成功的话）
//和URLSession:task:didCompleteWithError:（成功或者失败都会调用）方法做处理，以上的回调代码块可以在这里调用
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    
    // Identify the operation that runs this task and pass it the delegate method
    SDWebImageDownloaderOperation *dataOperation = [self operationWithTask:task];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [dataOperation URLSession:session task:task didCompleteWithError:error];
    }
}
//告诉委托远程服务器请求HTTP重定向。
//此方法仅适用于默认和临时会话中的任务。 后台会话中的任务会自动遵循重定向。
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    SDWebImageDownloaderOperation *dataOperation = [self operationWithTask:task];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) {
        [dataOperation URLSession:session task:task willPerformHTTPRedirection:response newRequest:request completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(request);
        }
    }
}
//  如果服务器要求验证客户端身份或向客户端提供其证书用于验证时，则会调用
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {

    // Identify the operation that runs this task and pass it the delegate method
    SDWebImageDownloaderOperation *dataOperation = [self operationWithTask:task];
    if ([dataOperation respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [dataOperation URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
    } else {
        if (completionHandler) {
            completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
        }
    }
}

@end
