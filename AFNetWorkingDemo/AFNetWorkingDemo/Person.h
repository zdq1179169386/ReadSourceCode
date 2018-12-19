//
//  Person.h
//  AFNetWorkingDemo
//
//  Created by qrh on 2018/12/19.
//  Copyright © 2018 zdq. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Person : NSObject

@property (nonatomic, copy) NSString * name;
@property (nonatomic, assign) NSUInteger age;
@property (nonatomic, copy) NSString * info;

@end

NS_ASSUME_NONNULL_END
