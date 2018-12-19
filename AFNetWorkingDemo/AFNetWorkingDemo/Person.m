//
//  Person.m
//  AFNetWorkingDemo
//
//  Created by qrh on 2018/12/19.
//  Copyright © 2018 zdq. All rights reserved.
//

#import "Person.h"

@implementation Person

- (void)setInfo:(NSString *)info
{
    
}

- (NSString *)info
{
    return [NSString stringWithFormat:@"name = %@,age = %@",_name,@(_age)];
}
//依赖建注册
+ (NSSet<NSString *> *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
    NSSet * set = [super keyPathsForValuesAffectingValueForKey:key];
    if ([key isEqualToString:@"info"]) {
        NSSet * keys = [NSSet setWithObjects:@"name",@"age", nil];
        [set setByAddingObjectsFromSet:keys];
    }
    return set;
}
@end
