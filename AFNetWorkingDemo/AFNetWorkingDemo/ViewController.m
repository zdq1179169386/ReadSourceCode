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

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self get];
    [self post];
//    [self test];
//    [self download];
    //    __Require_Quiet（当条件返回false时，执行标记以后的代码）
    __Require_Quiet(1,_out);
    NSLog(@"2222");
_out:
    NSLog(@"1111");
    
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
@end
