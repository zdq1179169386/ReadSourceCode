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
    
}


@end
