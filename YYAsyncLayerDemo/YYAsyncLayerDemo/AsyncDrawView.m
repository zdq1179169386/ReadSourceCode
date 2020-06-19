//
//  AsyncDrawView.m
//  YYAsyncLayerDemo
//
//  Created by ZDQ on 2020/3/11.
//  Copyright © 2020 zdq. All rights reserved.
//

#import "AsyncDrawView.h"
#import "MyLayer.h"
#import "YYTransaction.h"

@implementation AsyncDrawView


- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        self.layer.delegate = self;
    }
    return self;
}

+ (Class)layerClass
{
    return [MyLayer class];
}
- (void)setNeedsDisplay
{
    [super setNeedsDisplay];
    NSLog(@"%s",__func__);
    [self.layer setNeedsDisplay];
}

- (void)displayLayer:(CALayer *)layer
{
    NSLog(@"%s",__func__);
}

@end
