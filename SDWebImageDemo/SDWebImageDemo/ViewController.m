//
//  ViewController.m
//  SDWebImageDemo
//
//  Created by qrh on 2018/12/13.
//  Copyright © 2018 zdq. All rights reserved.
//

#import "ViewController.h"
#import <UIImageView+WebCache.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    [self.imageView sd_setImageWithURL:[NSURL URLWithString:@"https://oss.zhihanyun.com/Fg8_VDWkEBNFVyFxlsUGavJLusyk"] placeholderImage:nil];
    NSURL * url = [NSURL URLWithString:@"http://www.baidu.com"];
    SDHTTPHeadersDictionary * dict1 = @{@"Accept": @"image/webp,image/*;q=0.8"};
    self.headerBlock = ^SDHTTPHeadersDictionary * _Nullable(NSURL * _Nullable url, SDHTTPHeadersDictionary * _Nullable headers) {
        return @{url.absoluteString : headers};
    };
    SDHTTPHeadersDictionary * dict = self.headerBlock(url,dict1);
    NSLog(@"%@",dict);
    
}


@end
