//
//  ViewController.h
//  SDWebImageDemo
//
//  Created by qrh on 2018/12/13.
//  Copyright © 2018 zdq. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef NSDictionary<NSString *, NSString *> SDHTTPHeadersDictionary;


typedef SDHTTPHeadersDictionary * _Nullable (^SDWebImageDownloaderHeadersFilterBlock)(NSURL * _Nullable url, SDHTTPHeadersDictionary * _Nullable headers);



@interface ViewController : UIViewController

@property (nonatomic, copy,nullable) SDWebImageDownloaderHeadersFilterBlock  headerBlock;
@end

