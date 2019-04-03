//
//  AppDelegate.m
//  AFNetWorkingDemo
//
//  Created by qrh on 2018/12/18.
//  Copyright © 2018 zdq. All rights reserved.
//

#import "AppDelegate.h"
#import "AFNetworkActivityIndicatorManager.h"
#import <CoreTelephony/CTCellularData.h>
#import "AFNetworking.h"
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    NSURLCache *URLCache = [[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024 diskCapacity:20 * 1024 * 1024 diskPath:nil];
    [NSURLCache setSharedURLCache:URLCache];
    
//   状态栏上的菊花
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
    if (__IPHONE_10_0) {
        
    }
    [self cellularData];
    return YES;
}
- (void)cellularData{
    CTCellularData *cellularData = [[CTCellularData alloc] init];
    // 状态发生变化时调用
    cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState restrictedState) {
        switch (restrictedState) {
                case kCTCellularDataRestrictedStateUnknown:
                NSLog(@"蜂窝移动网络状态：未知");
                break;
                case kCTCellularDataRestricted:
                NSLog(@"蜂窝移动网络状态：关闭");
                break;
                case kCTCellularDataNotRestricted:
                NSLog(@"蜂窝移动网络状态：开启");
                break;
                
            default:
                break;
        }
    };
}
- (void)startMonitoring{
    AFNetworkReachabilityManager * manager = [AFNetworkReachabilityManager manager];
    [manager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
                case AFNetworkReachabilityStatusUnknown:
                
                break;
                case AFNetworkReachabilityStatusNotReachable:
                
                break;
                case AFNetworkReachabilityStatusReachableViaWWAN:
                
                break;
                case AFNetworkReachabilityStatusReachableViaWiFi:
                
                break;
            default:
                break;
        }
    }];
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
