//
//  AppDelegate.m
//  YYKitExample
//
//  Created by ibireme on 14-9-18.
//  Copyright (c) 2014 ibireme. All rights reserved.
//

#import "YYAppDelegate.h"
#import "YYRootViewController.h"

/// Fix the navigation bar height when hide status bar.
@interface YYExampleNavBar : UINavigationBar
@end

@implementation YYExampleNavBar {
    CGSize _previousSize;
}

- (CGSize)sizeThatFits:(CGSize)size {
    size = [super sizeThatFits:size];
    if ([UIApplication sharedApplication].statusBarHidden) {
        size.height = 64;
    }
    return size;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (!CGSizeEqualToSize(self.bounds.size, _previousSize)) {
        _previousSize = self.bounds.size;
        [self.layer removeAllAnimations];
        [self.layer.sublayers makeObjectsPerformSelector:@selector(removeAllAnimations)];
    }
}

@end

@interface YYExampleNavController : UINavigationController
@end
@implementation YYExampleNavController
- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

@end



@implementation YYAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    YYRootViewController *root = [YYRootViewController new];
    YYExampleNavController *nav = [[YYExampleNavController alloc] initWithNavigationBarClass:[YYExampleNavBar class] toolbarClass:[UIToolbar class]];
    if ([nav respondsToSelector:@selector(setAutomaticallyAdjustsScrollViewInsets:)]) {
        nav.automaticallyAdjustsScrollViewInsets = NO;
    }
    [nav pushViewController:root animated:NO];
    
    self.rootViewController = nav;
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = self.rootViewController;
    self.window.backgroundColor = [UIColor grayColor];
    [self.window makeKeyAndVisible];
//    [self test];
    return YES;
}

- (void)test{
    dispatch_semaphore_t signal;
    signal = dispatch_semaphore_create(1);
    __block long x = 0;
    NSLog(@"0_x:%ld",x);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        sleep(1);
        NSLog(@"waiting");
        x = dispatch_semaphore_signal(signal);
        NSLog(@"1_x:%ld",x);
        
        sleep(2);
        NSLog(@"waking");
        x = dispatch_semaphore_signal(signal);
        NSLog(@"2_x:%ld",x);
    });
    //    dispatch_time_t duration = dispatch_time(DISPATCH_TIME_NOW, 1*1000*1000*1000); //超时1秒
    //    dispatch_semaphore_wait(signal, duration);
    
    x = dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    NSLog(@"3_x:%ld",x);
    
    x = dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    NSLog(@"wait 2");
    NSLog(@"4_x:%ld",x);
    
    x = dispatch_semaphore_wait(signal, DISPATCH_TIME_FOREVER);
    NSLog(@"wait 3");
    NSLog(@"5_x:%ld",x);
}

@end
