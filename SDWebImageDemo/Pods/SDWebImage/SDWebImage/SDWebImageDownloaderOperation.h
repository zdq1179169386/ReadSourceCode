/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <Foundation/Foundation.h>
#import "SDWebImageDownloader.h"
#import "SDWebImageOperation.h"

FOUNDATION_EXPORT NSString * _Nonnull const SDWebImageDownloadStartNotification;
FOUNDATION_EXPORT NSString * _Nonnull const SDWebImageDownloadReceiveResponseNotification;
FOUNDATION_EXPORT NSString * _Nonnull const SDWebImageDownloadStopNotification;
FOUNDATION_EXPORT NSString * _Nonnull const SDWebImageDownloadFinishNotification;



/**
 Describes a downloader operation. If one wants to use a custom downloader op, it needs to inherit from `NSOperation` and conform to this protocol
 For the description about these methods, see `SDWebImageDownloaderOperation`
 */
//SDWebImageDownloader 中的 operationClass 可以设置成自定义的 operation ，但必须实现这个 SDWebImageDownloaderOperationInterface 协议
@protocol SDWebImageDownloaderOperationInterface<NSObject>

- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(SDWebImageDownloaderOptions)options;
//给Operation添加进度和回调Block
- (nullable id)addHandlersForProgress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                            completed:(nullable SDWebImageDownloaderCompletedBlock)completedBlock;
//是否需要解码
- (BOOL)shouldDecompressImages;
- (void)setShouldDecompressImages:(BOOL)value;
//是否需要设置凭证
- (nullable NSURLCredential *)credential;
- (void)setCredential:(nullable NSURLCredential *)value;

- (BOOL)cancel:(nullable id)token;

@end


@interface SDWebImageDownloaderOperation : NSOperation <SDWebImageDownloaderOperationInterface, SDWebImageOperation, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

/**
 * The request used by the operation's task.
 */
//操作者的任务使用的请求
@property (strong, nonatomic, readonly, nullable) NSURLRequest *request;

/**
 * The operation's task
 */
//操作的任务。
@property (strong, nonatomic, readonly, nullable) NSURLSessionTask *dataTask;

//是否解压缩图片(来源于协议SDWebImageDownloaderOperationInterface)
@property (assign, nonatomic) BOOL shouldDecompressImages;

/**
 *  Was used to determine whether the URL connection should consult the credential storage for authenticating the connection.
 *  @deprecated Not used for a couple of versions
 */
//用于判断URL连接是否应该为授权验证连接查询凭据存储。
@property (nonatomic, assign) BOOL shouldUseCredentialStorage __deprecated_msg("Property deprecated. Does nothing. Kept only for backwards compatibility");

/**
 * The credential used for authentication challenges in `-URLSession:task:didReceiveChallenge:completionHandler:`.
 *
 * This will be overridden by any shared credentials that exist for the username or password of the request URL, if present.
 */
//为请求操作设置默认的URL证书。(来源于协议SDWebImageDownloaderOperationInterface)
@property (nonatomic, strong, nullable) NSURLCredential *credential;

/**
 * The SDWebImageDownloaderOptions for the receiver.
 */
//接受器使用的SDWebImageDownloaderOperations。
@property (assign, nonatomic, readonly) SDWebImageDownloaderOptions options;

/**
 * The expected size of data.
 */
//期望的数据大小。
@property (assign, nonatomic) NSInteger expectedSize;

/**
 * The response returned by the operation's task.
 */
@property (strong, nonatomic, nullable) NSURLResponse *response;

/**
 *  Initializes a `SDWebImageDownloaderOperation` object
 *
 *  @see SDWebImageDownloaderOperation
 *
 *  @param request        the URL request
 *  @param session        the URL session in which this operation will run
 *  @param options        downloader options
 *
 *  @return the initialized instance
 */
- (nonnull instancetype)initWithRequest:(nullable NSURLRequest *)request
                              inSession:(nullable NSURLSession *)session
                                options:(SDWebImageDownloaderOptions)options NS_DESIGNATED_INITIALIZER;

/**
 *  Adds handlers for progress and completion. Returns a tokent that can be passed to -cancel: to cancel this set of
 *  callbacks.
 *
 *  @param progressBlock  the block executed when a new chunk of data arrives.
 *                        @note the progress block is executed on a background queue
 *  @param completedBlock the block executed when the download is done.
 *                        @note the completed block is executed on the main queue for success. If errors are found, there is a chance the block will be executed on a background queue
 *
 *  @return the token to use to cancel this set of handlers
 */
- (nullable id)addHandlersForProgress:(nullable SDWebImageDownloaderProgressBlock)progressBlock
                            completed:(nullable SDWebImageDownloaderCompletedBlock)completedBlock;

/**
 *  Cancels a set of callbacks. Once all callbacks are canceled, the operation is cancelled.
 *
 *  @param token the token representing a set of callbacks to cancel
 *
 *  @return YES if the operation was stopped because this was the last token to be canceled. NO otherwise.
 */
- (BOOL)cancel:(nullable id)token;

@end
