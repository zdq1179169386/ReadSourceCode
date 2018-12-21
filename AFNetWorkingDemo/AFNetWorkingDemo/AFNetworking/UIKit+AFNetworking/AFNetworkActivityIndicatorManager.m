// AFNetworkActivityIndicatorManager.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "AFNetworkActivityIndicatorManager.h"

#if TARGET_OS_IOS
#import "AFURLSessionManager.h"
/*原来这是AF对请求菊花显示做的一个优化处理，试问如果一个请求时间很短，那么菊花很可能闪一下就结束了。如果很多请求过来，那么菊花会不停的闪啊闪，这显然并不是我们想要的效果。*/
typedef NS_ENUM(NSInteger, AFNetworkActivityManagerState) {
    //没有请求
    AFNetworkActivityManagerStateNotActive,
    //请求延迟开始
    AFNetworkActivityManagerStateDelayingStart,
    //请求进行中
    AFNetworkActivityManagerStateActive,
    //请求延迟结束
    AFNetworkActivityManagerStateDelayingEnd
};

static NSTimeInterval const kDefaultAFNetworkActivityManagerActivationDelay = 1.0;
static NSTimeInterval const kDefaultAFNetworkActivityManagerCompletionDelay = 0.17;

static NSURLRequest * AFNetworkRequestFromNotification(NSNotification *notification) {
    if ([[notification object] respondsToSelector:@selector(originalRequest)]) {
        return [(NSURLSessionTask *)[notification object] originalRequest];
    } else {
        return nil;
    }
}

typedef void (^AFNetworkActivityActionBlock)(BOOL networkActivityIndicatorVisible);

@interface AFNetworkActivityIndicatorManager ()
@property (readwrite, nonatomic, assign) NSInteger activityCount;
@property (readwrite, nonatomic, strong) NSTimer *activationDelayTimer;
@property (readwrite, nonatomic, strong) NSTimer *completionDelayTimer;
@property (readonly, nonatomic, getter = isNetworkActivityOccurring) BOOL networkActivityOccurring;
@property (nonatomic, copy) AFNetworkActivityActionBlock networkActivityActionBlock;
@property (nonatomic, assign) AFNetworkActivityManagerState currentState;
@property (nonatomic, assign, getter=isNetworkActivityIndicatorVisible) BOOL networkActivityIndicatorVisible;

- (void)updateCurrentStateForNetworkActivityChange;
@end

@implementation AFNetworkActivityIndicatorManager

+ (instancetype)sharedManager {
    static AFNetworkActivityIndicatorManager *_sharedManager = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedManager = [[self alloc] init];
    });

    return _sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.currentState = AFNetworkActivityManagerStateNotActive;
/*
 还记得我们之前讲的AF对NSURLSessionTask中做了一个Method Swizzling吗？大意是把它的resume和suspend方法做了一个替换，在原有实现的基础上添加了一个通知的发送。*/
//    开始下载通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkRequestDidStart:) name:AFNetworkingTaskDidResumeNotification object:nil];
//    挂起通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkRequestDidFinish:) name:AFNetworkingTaskDidSuspendNotification object:nil];
//    完成通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkRequestDidFinish:) name:AFNetworkingTaskDidCompleteNotification object:nil];
    //开始延迟
    self.activationDelay = kDefaultAFNetworkActivityManagerActivationDelay;
    //结束延迟
    self.completionDelay = kDefaultAFNetworkActivityManagerCompletionDelay;

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_activationDelayTimer invalidate];
    [_completionDelayTimer invalidate];
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    if (enabled == NO) {
        [self setCurrentState:AFNetworkActivityManagerStateNotActive];
    }
}

- (void)setNetworkingActivityActionWithBlock:(void (^)(BOOL networkActivityIndicatorVisible))block {
    self.networkActivityActionBlock = block;
}

- (BOOL)isNetworkActivityOccurring {
    @synchronized(self) {
        return self.activityCount > 0;
    }
}

- (void)setNetworkActivityIndicatorVisible:(BOOL)networkActivityIndicatorVisible {
    if (_networkActivityIndicatorVisible != networkActivityIndicatorVisible) {
        [self willChangeValueForKey:@"networkActivityIndicatorVisible"];
        @synchronized(self) {
             _networkActivityIndicatorVisible = networkActivityIndicatorVisible;
        }
        [self didChangeValueForKey:@"networkActivityIndicatorVisible"];
        if (self.networkActivityActionBlock) {
            self.networkActivityActionBlock(networkActivityIndicatorVisible);
        } else {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:networkActivityIndicatorVisible];
        }
    }
}

- (void)setActivityCount:(NSInteger)activityCount {
	@synchronized(self) {
		_activityCount = activityCount;
	}

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCurrentStateForNetworkActivityChange];
    });
}
//增加请求活跃数
- (void)incrementActivityCount {
     //活跃的网络数+1，并手动发送KVO
    [self willChangeValueForKey:@"activityCount"];
//    同步锁
	@synchronized(self) {
		_activityCount++;
	}
    [self didChangeValueForKey:@"activityCount"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCurrentStateForNetworkActivityChange];
    });
}
// 减少请求活跃数
- (void)decrementActivityCount {
    [self willChangeValueForKey:@"activityCount"];
	@synchronized(self) {
		_activityCount = MAX(_activityCount - 1, 0);
	}
    [self didChangeValueForKey:@"activityCount"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCurrentStateForNetworkActivityChange];
    });
}
//请求开始
- (void)networkRequestDidStart:(NSNotification *)notification {
    if ([AFNetworkRequestFromNotification(notification) URL]) {
        //增加请求活跃数
        [self incrementActivityCount];
    }
}
//请求结束
- (void)networkRequestDidFinish:(NSNotification *)notification {
    if ([AFNetworkRequestFromNotification(notification) URL]) {
//      减少请求活跃数
        [self decrementActivityCount];
    }
}

#pragma mark - Internal State Management
//重写set 方法，设置当前小菊花状态
- (void)setCurrentState:(AFNetworkActivityManagerState)currentState {
    @synchronized(self) {
        if (_currentState != currentState) {
            [self willChangeValueForKey:@"currentState"];
            _currentState = currentState;
            switch (currentState) {
//                    不活跃
                case AFNetworkActivityManagerStateNotActive:
                    //取消两个延迟用的timer
                    [self cancelActivationDelayTimer];
                    [self cancelCompletionDelayTimer];
//                    菊花隐藏
                    [self setNetworkActivityIndicatorVisible:NO];
                    break;
                case AFNetworkActivityManagerStateDelayingStart:
//                    开启定时器
                    [self startActivationDelayTimer];
                    break;
//                    活跃状态
                case AFNetworkActivityManagerStateActive:
                    //取消延迟完成的timer
                    [self cancelCompletionDelayTimer];
                    //开始转菊花
                    [self setNetworkActivityIndicatorVisible:YES];
                    break;
                    //延迟完成状态
                case AFNetworkActivityManagerStateDelayingEnd:
                    //开启延迟完成timer
                    [self startCompletionDelayTimer];
                    break;
            }
            [self didChangeValueForKey:@"currentState"];
        }
        
    }
}

- (void)updateCurrentStateForNetworkActivityChange {
//如果是允许小菊花
    if (self.enabled) {
        switch (self.currentState) {
//                不活跃
            case AFNetworkActivityManagerStateNotActive:
                //判断活跃数，大于0为YES
                if (self.isNetworkActivityOccurring) {
                    //设置状态为延迟开始
                    [self setCurrentState:AFNetworkActivityManagerStateDelayingStart];
                }
                break;
            case AFNetworkActivityManagerStateDelayingStart:
                //No op. Let the delay timer finish out.
//                延迟开始不作处理
                break;
            case AFNetworkActivityManagerStateActive:
                if (!self.isNetworkActivityOccurring) {
//                    判断活跃数，设置延迟结束
                    [self setCurrentState:AFNetworkActivityManagerStateDelayingEnd];
                }
                break;
            case AFNetworkActivityManagerStateDelayingEnd:
                if (self.isNetworkActivityOccurring) {
//                    活跃数大于0，设置请求进行中
                    [self setCurrentState:AFNetworkActivityManagerStateActive];
                }
                break;
        }
    }
}
////开始任务到结束的时间，默认为1秒，如果1秒就结束，那么不转菊花，延迟去开始转
- (void)startActivationDelayTimer {
    self.activationDelayTimer = [NSTimer
                                 timerWithTimeInterval:self.activationDelay target:self selector:@selector(activationDelayTimerFired) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.activationDelayTimer forMode:NSRunLoopCommonModes];
}

- (void)activationDelayTimerFired {
    if (self.networkActivityOccurring) {
        //活跃状态，即活跃数大于1才转
        [self setCurrentState:AFNetworkActivityManagerStateActive];
    } else {
        [self setCurrentState:AFNetworkActivityManagerStateNotActive];
    }
}
//完成任务到下一个任务开始，默认为0.17秒，如果0.17秒就开始下一个，那么不停  延迟去结束菊花转
- (void)startCompletionDelayTimer {
    [self.completionDelayTimer invalidate];
    self.completionDelayTimer = [NSTimer timerWithTimeInterval:self.completionDelay target:self selector:@selector(completionDelayTimerFired) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.completionDelayTimer forMode:NSRunLoopCommonModes];
}

- (void)completionDelayTimerFired {
    [self setCurrentState:AFNetworkActivityManagerStateNotActive];
}

- (void)cancelActivationDelayTimer {
    [self.activationDelayTimer invalidate];
}

- (void)cancelCompletionDelayTimer {
    [self.completionDelayTimer invalidate];
}

@end

#endif
