//
//  ViewController.m
//  SDWebImageDemo
//
//  Created by qrh on 2018/12/13.
//  Copyright © 2018 zdq. All rights reserved.
//

#import "ViewController.h"
//#import <UIImageView+WebCache.h>
//#import <SDWebImage/SDWebImageDownloader.h>
#import "UIImageView+WebCache.h"
#import "SDWebImage/SDWebImageDownloader.h"
@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
//    [self.imageView sd_setImageWithURL:[NSURL URLWithString:@"https://oss.zhihanyun.com/Fg8_VDWkEBNFVyFxlsUGavJLusyk"] placeholderImage:[UIImage imageNamed:@"bc_img_placeholder"]];
    
//    当我通过 [SDWebImagePrefetcher sharedImagePrefetcher] prefetchURLs 提前下载了图片，这里就可以直接从缓存中取了。
//    NSString * cacheKey = [[SDWebImageManager sharedManager] cacheKeyForURL:[NSURL URLWithString:@"https://oss.zhihanyun.com/Fg8_VDWkEBNFVyFxlsUGavJLusyk"]];
//    self.imageView.image = [[SDImageCache sharedImageCache] imageFromCacheForKey: cacheKey];
    
//    [self test];
    
//   SDWebImageProgressiveDownload ： 渐进式解码
   [self.imageView sd_setImageWithURL:[NSURL URLWithString:@"https://oss.zhihanyun.com/Fg8_VDWkEBNFVyFxlsUGavJLusyk"] placeholderImage:[UIImage imageNamed:@"bc_img_placeholder"] options:(SDWebImageDelayPlaceholder)];
    
//  获取当前队列的名字
    NSLog(@"%s", dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL));
    
}
- (void)test {
    NSString *str1 = [[NSString alloc] init];
    NSString *str2 = [[NSString alloc] init];
    NSString *str3 = [str1 stringByAppendingFormat:@"字符串"];
    NSString *str4 = [str2 stringByAppendingFormat:@"字符串"];
    
    NSMutableArray *muArray = [NSMutableArray arrayWithCapacity:6];
    [muArray addObject:@"对象"];
    [muArray addObject:str3];
    [muArray addObject:str4];
    for (NSObject * object in muArray) {
        NSLog(@"数组对象:%@", object);
    }
    
    
    if ([str3 isEqual:str4]) {
        NSLog(@"str1 isEqual str2");
    }
    if (str3 == str4) {
        NSLog(@"str1 == str2");
    }
//    [muArray removeObject:str3];
     [muArray removeObjectIdenticalTo:str3];
    for (NSObject * object in muArray) {
        NSLog(@"数组对象:%@", object);
    }
    
}
- (void)test1{
    NSURL * url = [NSURL URLWithString:@"http://www.baidu.com"];
    SDHTTPHeadersDictionary * dict1 = @{@"Accept": @"image/webp,image/*;q=0.8"};
    self.headerBlock = ^SDHTTPHeadersDictionary * _Nullable(NSURL * _Nullable url, SDHTTPHeadersDictionary * _Nullable headers) {
        return @{url.absoluteString : headers};
    };
    SDHTTPHeadersDictionary * dict = self.headerBlock(url,dict1);
    NSLog(@"%@",dict);
}
@end





