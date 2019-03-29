//
//  ViewController.m
//  YYAsyncLayerDemo
//
//  Created by qrh on 2019/2/13.
//  Copyright © 2019 zdq. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

static void callBack(CFRunLoopObserverRef observer,CFRunLoopActivity activity,void * info){
    NSLog(@"activity = %@",@(activity));
}

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self demo2];
}
- (void)demo1{
    NSLog(@"1"); // 任务1
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"2"); // 任务2
        NSLog(@" currentThread = %@",[NSThread currentThread]);
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"3"); // 任务3
            NSLog(@" currentThread = %@",[NSThread currentThread]);
        });
        NSLog(@"4"); // 任务4
    });
    NSLog(@"5"); // 任务5
}
- (void)demo{
    dispatch_queue_t  q = dispatch_get_main_queue();
    dispatch_queue_t ser_queue = dispatch_queue_create("Ser", DISPATCH_QUEUE_SERIAL);
    dispatch_sync(ser_queue, ^{
        NSLog(@"1");
        NSLog(@" currentThread = %@",[NSThread currentThread]);
    });
    
    NSLog(@"2");
}
- (void)demo2{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"1"); // 任务1
        dispatch_sync(dispatch_get_main_queue(), ^{
            NSLog(@"2"); // 任务2
        });
        NSLog(@"3"); // 任务3
    });
    NSLog(@"4"); // 任务4
    while (1) {
    }
    NSLog(@"5"); // 任务5
}
- (void)addRunloopObserver{
    CFRunLoopRef runloop = CFRunLoopGetMain();
    CFRunLoopObserverRef observer;
    observer = CFRunLoopObserverCreate(CFAllocatorGetDefault(), kCFRunLoopBeforeWaiting | kCFRunLoopExit, true, 0xFFFFFF, callBack, NULL);
    CFRunLoopAddObserver(runloop, observer, kCFRunLoopCommonModes);
    CFRelease(observer);

}
@end
