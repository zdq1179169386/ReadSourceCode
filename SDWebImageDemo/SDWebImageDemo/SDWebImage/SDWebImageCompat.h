/*
 * This file is part of the SDWebImage package.
 * (c) Olivier Poitrey <rs@dailymotion.com>
 * (c) Jamie Pinkham
 *
 * For the full copyright and license information, please view the LICENSE
 * file that was distributed with this source code.
 */

#import <TargetConditionals.h>
/*
 Objective-C 支持内存的垃圾回收机制（Garbage collection 简称：GC）。在Mac开发是支持的，但是在iOS 开发中使用MRC／ARC，是不支持GC 的。iOS 5 之后开始支持ARC ，帮助开发者更好的管理内存，简化内存管理的难度并提高开发效率。SDWebImage 不支持GC，如果宏定义过 __OBJC_GC__，则表示是在支持GC 的开发环境，直接报错（#error）。当启动GC时，所有的retain、autorelease、release 和dealloc 方法都将被系统忽略。*/
#ifdef __OBJC_GC__
    #error SDWebImage does not support Objective-C Garbage Collection
#endif

// Apple's defines from TargetConditionals.h are a bit weird.
// Seems like TARGET_OS_MAC is always defined (on all platforms).
// To determine if we are running on OSX, we can only rely on TARGET_OS_IPHONE=0 and all the other platforms
/*
 。TARGET_OS_MAC 定义在所有的平台中，比如MAC、iPhone、Watch、TV等，因此单纯的使用TARGET_OS_MAC 判断当前是不是MAC 平台是不可行的。但按照上面的判断方式，也存在一个缺点：当Apple出现新的平台时，判断条件要修改。*/
#if !TARGET_OS_IPHONE && !TARGET_OS_IOS && !TARGET_OS_TV && !TARGET_OS_WATCH
    #define SD_MAC 1
#else
    #define SD_MAC 0
#endif

// iOS and tvOS are very similar, UIKit exists on both platforms
// Note: watchOS also has UIKit, but it's very limited
/*
 UIKit在这两个平台中都存在，但是watchOS在使用UIKit时，是受限的。因此定义SD_UIKIT为真的条件是iOS 和 tvOS这两个平台。*/
#if TARGET_OS_IOS || TARGET_OS_TV
    #define SD_UIKIT 1
#else
    #define SD_UIKIT 0
#endif

#if TARGET_OS_IOS
    #define SD_IOS 1
#else
    #define SD_IOS 0
#endif

#if TARGET_OS_TV
    #define SD_TV 1
#else
    #define SD_TV 0
#endif

#if TARGET_OS_WATCH
    #define SD_WATCH 1
#else
    #define SD_WATCH 0
#endif

/*
 如果SD_MAC 为真，表示在macOS 平台上开发，引入 并定义了三个宏 UIImage/UIImageView/UIView；
 SDWebImage 不支持iOS 5.0 以下的版本；
 SD_UIKIT 为真时引入 <UIKit/UIKit.h>；
 SD_WATCH 为真时引入 <WatchKit/WatchKit.h>。
 */
#if SD_MAC
    #import <AppKit/AppKit.h>
    #ifndef UIImage
        #define UIImage NSImage
    #endif
    #ifndef UIImageView
        #define UIImageView NSImageView
    #endif
    #ifndef UIView
        #define UIView NSView
    #endif
#else
    #if __IPHONE_OS_VERSION_MIN_REQUIRED != 20000 && __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_5_0
        #error SDWebImage doesn't support Deployment Target version < 5.0
    #endif

    #if SD_UIKIT
        #import <UIKit/UIKit.h>
    #endif
    #if SD_WATCH
        #import <WatchKit/WatchKit.h>
        #ifndef UIView
            #define UIView WKInterfaceObject
        #endif
        #ifndef UIImageView
            #define UIImageView WKInterfaceImage
        #endif
    #endif
#endif

#ifndef NS_ENUM
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#endif

#ifndef NS_OPTIONS
#define NS_OPTIONS(_type, _name) enum _name : _type _name; enum _name : _type
#endif

FOUNDATION_EXPORT UIImage *SDScaledImageForKey(NSString *key, UIImage *image);

typedef void(^SDWebImageNoParamsBlock)(void);

FOUNDATION_EXPORT NSString *const SDWebImageErrorDomain;

/*
 如果当前线程已经是主线程，那么在调用dispatch_async(dispatch_get_main_queue(), block)有可能会出现crash。因此做了一个判断：当前线程是主线程，直接调用Block；如果不是，那么调用dispatch_async(dispatch_get_main_queue(), block)。*/

#ifndef dispatch_queue_async_safe
#define dispatch_queue_async_safe(queue, block)\
    if (dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL) == dispatch_queue_get_label(queue)) {\
        block();\
    } else {\
        dispatch_async(queue, block);\
    }
#endif

#ifndef dispatch_main_async_safe
#define dispatch_main_async_safe(block) dispatch_queue_async_safe(dispatch_get_main_queue(), block)
#endif
