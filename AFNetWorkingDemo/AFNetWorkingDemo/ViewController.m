//
//  ViewController.m
//  AFNetWorkingDemo
//
//  Created by qrh on 2018/12/18.
//  Copyright © 2018 zdq. All rights reserved.
//

#import "ViewController.h"
#import "AFNetworking.h"
#import "Person.h"
#import <AssertMacros.h>

@interface ViewController ()
{
    Person * _p;
}
@property (weak, nonatomic) IBOutlet UILabel *infoLab;
@property (nonatomic, assign) NSInteger ticketSurplusCount;
@property (nonatomic, strong) NSLock * lock;
@property (nonatomic, strong) dispatch_semaphore_t smaphore;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    [self get];
//    [self post];
//    [self test];
//    [self download];
    //    __Require_Quiet（当条件返回false时，执行标记以后的代码）
   
/*
 __Require_Quiet(1,_out);
 NSLog(@"2222");
 _out:
 NSLog(@"1111");
 */
    
    
//    [self uploadImages2];
    
//    [self semaphoreSync2];
    self.lock = [NSLock new];
    self.smaphore = dispatch_semaphore_create(1);
    [self initTicketStatusNotSave];
    
}
- (void)get{
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc]initWithBaseURL:[NSURL URLWithString:@"http://www.sojson.com"]];
//    manager.requestSerializer.HTTPShouldUsePipelining = YES;
    [manager GET:@"/open/api/weather/json.shtml" parameters:@{@"city":@"北京"} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
//        NSLog(@"responseObject = %@", responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"error = %@", error);
    }];
}
- (void)post{
//  https://blog.csdn.net/c__chao/article/details/78573737 免费的api 接口
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
//    form 表单提交
    [manager.requestSerializer setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    manager.requestSerializer.timeoutInterval = 30;
    manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
//    manager.requestSerializer.HTTPShouldUsePipelining = YES;
    [manager.requestSerializer setAuthorizationHeaderFieldWithUsername:@"zdq" password:@"123"];
    manager.responseSerializer.acceptableContentTypes  =  [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain",@"application/xml", @"multipart/form-data", nil];
    NSString * urlStr = @"https://www.apiopen.top/journalismApi";
    [manager setDataTaskWillCacheResponseBlock:^NSCachedURLResponse * _Nonnull(NSURLSession * _Nonnull session, NSURLSessionDataTask * _Nonnull dataTask, NSCachedURLResponse * _Nonnull proposedResponse) {
        NSLog(@"proposedResponse = %@",proposedResponse);
        return proposedResponse;
    }];
    [manager POST:urlStr parameters:nil progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSDictionary * responseDict = (NSDictionary *)responseObject;
        NSData * data = [NSJSONSerialization dataWithJSONObject:responseDict options:(NSJSONWritingPrettyPrinted) error:nil];
//        NSLog(@"responseObject = %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"error = %@", error);
    }];
}
- (void)test{
    Person * p = [Person new];
    p.name = @"jack";
    p.age = 11;
    self.infoLab.text = p.info;
    _p = p;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    _p.age ++;
    self.infoLab.text = _p.info;
}
- (void)upload{
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.requestSerializer.HTTPShouldUsePipelining = YES;
    [manager POST:@"postURLString" parameters:@{@"Filename":@"Test.txt"} constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:[NSData data]
                                    name:@"file000"
                                fileName:@"Test测试.txt"
                                mimeType:@"application/octet-stream"];
        [formData appendPartWithFormData:[@"Submit Query" dataUsingEncoding:NSUTF8StringEncoding]
                                    name:@"Upload"];
    } progress:nil success:nil failure:nil];

}
- (void)download {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSURL *URL = [NSURL URLWithString:@"http://dldir1.qq.com/qqfile/QQforMac/QQ_V5.4.0.dmg"];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    NSURLSessionDownloadTask * downloadTask = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        NSLog(@"%@",[NSString stringWithFormat:@"当前下载进度:%.2f%%",100.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount]);
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        NSURL *path = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        return [path URLByAppendingPathComponent:@"QQ_V5.4.0.dmg"];
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        NSLog(@"File downloaded to: %@", filePath);
    }];
    
    [downloadTask resume];
}
- (void)uploadImages{
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray * results = [[NSMutableArray alloc] initWithCapacity:9];
    for (NSInteger i = 0; i < 10; i++) {
        dispatch_group_enter(group);
        dispatch_async(dispatch_queue_create("zdq_queue", DISPATCH_QUEUE_CONCURRENT), ^{
            AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
            manager.requestSerializer.HTTPShouldUsePipelining = YES;
            NSLog(@"currentThread = %@",[NSThread currentThread]);
            [manager POST:@"postURLString" parameters:@{@"Filename":@"Test.txt"} constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
                [formData appendPartWithFileData:[NSData data]
                                            name:@"file000"
                                        fileName:@"Test测试.txt"
                                        mimeType:@"application/octet-stream"];
                [formData appendPartWithFormData:[@"Submit Query" dataUsingEncoding:NSUTF8StringEncoding]
                                            name:@"Upload"];
            } progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                if (responseObject) {
                    dispatch_group_leave(group);
                }
            } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                if (error) {
                    dispatch_group_leave(group);
                }
            }];
        });
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"上传完成");
    });
}
- (NSString *)uploadUrl{
    return @"";
}
- (NSURLSessionUploadTask*)uploadTaskWithImage:(UIImage*)image completion:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionBlock {
    // 构造 NSURLRequest
    NSError* error = NULL;
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer serializer] multipartFormRequestWithMethod:@"POST" URLString:[self uploadUrl] parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData> formData) {
        NSData* imageData = UIImageJPEGRepresentation(image, 1.0);
        [formData appendPartWithFileData:imageData name:@"file" fileName:@"someFileName" mimeType:@"multipart/form-data"];
    } error:&error];
    
    // 可在此处配置验证信息
    
    // 将 NSURLRequest 与 completionBlock 包装为 NSURLSessionUploadTask
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    NSURLSessionUploadTask *uploadTask = [manager uploadTaskWithStreamedRequest:request progress:^(NSProgress * _Nonnull uploadProgress) {
    } completionHandler:completionBlock];
    
    NSLog(@"uploadtask thread = %@",[NSThread currentThread]);
    
    return uploadTask;
}

- (void)uploadImages2{
    // 需要上传的数据
    NSMutableArray * images = [NSMutableArray new];
    
    for (NSInteger i = 1; i < 5; i++) {
        NSString * filepath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.jpg",@(i)]];
//        NSLog(@"filepath = %@",filepath);
        [images addObject:[UIImage imageWithContentsOfFile:filepath]];
    }
    
    // 准备保存结果的数组，元素个数与上传的图片个数相同，先用 NSNull 占位
    NSMutableArray* result = [NSMutableArray array];
    for (UIImage* image in images) {
        [result addObject:[NSNull null]];
    }
    
    dispatch_group_t group = dispatch_group_create();
    
    for (NSInteger i = 0; i < 4; i++) {
        
        dispatch_group_enter(group);
        
        NSURLSessionUploadTask* uploadTask = [self uploadTaskWithImage:images[i] completion:^(NSURLResponse *response, NSDictionary* responseObject, NSError *error) {
            if (error) {
                NSLog(@"第 %d 张图片上传失败: %@", (int)i + 1, error);
                dispatch_group_leave(group);
            } else {
                NSLog(@"第 %d 张图片上传成功: %@", (int)i + 1, responseObject);
                @synchronized (result) { // NSMutableArray 是线程不安全的，所以加个同步锁
                    result[i] = responseObject;
                }
                dispatch_group_leave(group);
            }
        }];
        NSLog(@"for thread = %@",[NSThread currentThread]);
        [uploadTask resume];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"上传完成!");
        for (id response in result) {
            NSLog(@"%@", response);
        }
    });
}
- (void)semaphoreSync {
    
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"semaphore---begin");
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
//    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    __block int number = 0;
    dispatch_async(queue, ^{
        // 追加任务1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);      // 打印当前线程
        
        number = 100;
        
//        dispatch_semaphore_signal(semaphore);
    });
    
//    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"semaphore---end,number = %zd",number);
}
- (void)semaphoreSync2 {
    
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"semaphore---begin");
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    __block int number = 0;
    dispatch_async(queue, ^{
        // 追加任务1
        [NSThread sleepForTimeInterval:2];              // 模拟耗时操作
        NSLog(@"1---%@",[NSThread currentThread]);      // 打印当前线程
        
        number = 100;
        
        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    NSLog(@"semaphore---end,number = %zd",number);
}

- (void)initTicketStatusNotSave {
    NSLog(@"currentThread---%@",[NSThread currentThread]);  // 打印当前线程
    NSLog(@"semaphore---begin");
    
    self.ticketSurplusCount = 100;
    
    // queue1 代表北京火车票售卖窗口
    dispatch_queue_t queue1 = dispatch_queue_create("net.bujige.testQueue1", DISPATCH_QUEUE_SERIAL);
    // queue2 代表上海火车票售卖窗口
    dispatch_queue_t queue2 = dispatch_queue_create("net.bujige.testQueue2", DISPATCH_QUEUE_SERIAL);
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(queue1, ^{
        [weakSelf saleTicketNotSafe];
    });
    
    dispatch_async(queue2, ^{
        [weakSelf saleTicketNotSafe];
    });
}

/**
 * 售卖火车票(非线程安全)
 */
- (void)saleTicketNotSafe {
    while (1) {
        [self.lock lock];
        if (self.ticketSurplusCount > 0) {  //如果还有票，继续售卖
            self.ticketSurplusCount--;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%d 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
            [NSThread sleepForTimeInterval:0.2];
        } else { //如果已卖完，关闭售票窗口
            NSLog(@"所有火车票均已售完");
            break;
        }
        [self.lock unlock];
    }
}
- (void)saleTicketNotSafe2 {
    while (1) {
        dispatch_semaphore_wait(self.smaphore, DISPATCH_TIME_FOREVER);
        if (self.ticketSurplusCount > 0) {  //如果还有票，继续售卖
            self.ticketSurplusCount--;
            NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%d 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
            [NSThread sleepForTimeInterval:0.2];
        } else { //如果已卖完，关闭售票窗口
            NSLog(@"所有火车票均已售完");
            break;
        }
        dispatch_semaphore_signal(self.smaphore);
    }
}
- (void)saleTicketNotSafe3 {
    while (1) {
        @synchronized (@(self.ticketSurplusCount)) {
            if (self.ticketSurplusCount > 0) {  //如果还有票，继续售卖
                self.ticketSurplusCount--;
                NSLog(@"%@", [NSString stringWithFormat:@"剩余票数：%d 窗口：%@", self.ticketSurplusCount, [NSThread currentThread]]);
                [NSThread sleepForTimeInterval:0.2];
            } else { //如果已卖完，关闭售票窗口
                NSLog(@"所有火车票均已售完");
                break;
            }
        }
    }
}


@end
