//
//  MyLayer.m
//  YYAsyncLayerDemo
//
//  Created by ZDQ on 2020/3/11.
//  Copyright © 2020 zdq. All rights reserved.
//

#import "MyLayer.h"

@implementation MyLayer

- (void)display
{
    [super display];
    NSLog(@"%s",__func__);
}
- (void)setNeedsDisplay
{
    [super setNeedsDisplay];
    NSLog(@"%s",__func__);
}

@end
