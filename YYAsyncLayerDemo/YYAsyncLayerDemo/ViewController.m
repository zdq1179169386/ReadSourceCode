//
//  ViewController.m
//  YYAsyncLayerDemo
//
//  Created by qrh on 2019/2/13.
//  Copyright © 2019 zdq. All rights reserved.
//

#import "ViewController.h"
#import "AsyncDrawView.h"

@interface ViewController ()
{
    AsyncDrawView * _drawView;
}
@end

static void callBack(CFRunLoopObserverRef observer,CFRunLoopActivity activity,void * info){
    NSLog(@"activity = %@",@(activity));
}

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self demo4];
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
- (void)demo3{
    //1.创建目标队列
    dispatch_queue_t targetQueue = dispatch_queue_create("test.target.queue", DISPATCH_QUEUE_SERIAL);
    
    //2.创建3个串行队列
    dispatch_queue_t queue1 = dispatch_queue_create("test.1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t queue2 = dispatch_queue_create("test.2", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t queue3 = dispatch_queue_create("test.3", DISPATCH_QUEUE_SERIAL);
    
    //3.将3个串行队列分别添加到目标队列
    dispatch_set_target_queue(queue1, targetQueue);
    dispatch_set_target_queue(queue2, targetQueue);
    dispatch_set_target_queue(queue3, targetQueue);
    
    
    dispatch_async(queue1, ^{
        NSLog(@"1 in");
        [NSThread sleepForTimeInterval:3.f];
        NSLog(@"1 out");
    });
    
    dispatch_async(queue2, ^{
        NSLog(@"2 in");
        [NSThread sleepForTimeInterval:2.f];
        NSLog(@"2 out");
    });
    dispatch_async(queue3, ^{
        NSLog(@"3 in");
        [NSThread sleepForTimeInterval:1.f];
        NSLog(@"3 out");
    });
}
- (void)demo4
{
    _drawView = [[AsyncDrawView alloc] initWithFrame:CGRectMake(100, 100, 100, 100)];
    _drawView.backgroundColor = [UIColor redColor];
    [self.view addSubview:_drawView];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    _drawView.frame = CGRectMake(100, 200, 100, 100);
    [_drawView setNeedsDisplay];
}


@end
