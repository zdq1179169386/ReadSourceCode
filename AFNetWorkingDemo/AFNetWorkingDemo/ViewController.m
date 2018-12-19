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
    
    [self test];
    //    __Require_Quiet（当条件返回false时，执行标记以后的代码）
    __Require_Quiet(1,_out);
    NSLog(@"2222");
_out:
    NSLog(@"1111");
    
}
- (void)get{
    AFHTTPSessionManager *manager = [[AFHTTPSessionManager alloc]initWithBaseURL:[NSURL URLWithString:@"http://www.sojson.com"]];
    [manager GET:@"/open/api/weather/json.shtml" parameters:@{@"city":@"北京"} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"responseObject = %@", responseObject);
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
//
    manager.responseSerializer.acceptableContentTypes  =  [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/plain",@"application/xml", @"multipart/form-data", nil];
    NSString * urlStr = @"https://www.apiopen.top/journalismApi";
    [manager POST:urlStr parameters:nil progress:^(NSProgress * _Nonnull uploadProgress) {
        
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSLog(@"responseObject = %@", responseObject);
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
@end
