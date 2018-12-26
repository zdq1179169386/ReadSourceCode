//
//  YERootViewController.m
//  YYKitExample
//
//  Created by ibireme on 14-10-13.
//  Copyright (c) 2014 ibireme. All rights reserved.
//

#import "YYRootViewController.h"
#import "YYKit.h"
#import "WBModel.h"
@interface YYRootViewController ()
@property (nonatomic, strong) NSMutableArray *titles;
@property (nonatomic, strong) NSMutableArray *classNames;
@end

@implementation YYRootViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"YYKit Example";
    self.titles = @[].mutableCopy;
    self.classNames = @[].mutableCopy;
    [self addCell:@"Model" class:@"YYModelExample"];
    [self addCell:@"Image" class:@"YYImageExample"];
    [self addCell:@"Text" class:@"YYTextExample"];
    //    [self addCell:@"Utility" class:@"YYUtilityExample"];
    [self addCell:@"Feed List Demo" class:@"YYFeedListExample"];
    [self.tableView reloadData];
    
    //[self log];
    
    //    [self test1];
    [self test3];

}

- (void)log {
    printf("all:%.2f MB   used:%.2f MB   free:%.2f MB   active:%.2f MB  inactive:%.2f MB  wird:%.2f MB  purgable:%.2f MB\n",
           [UIDevice currentDevice].memoryTotal / 1024.0 / 1024.0,
           [UIDevice currentDevice].memoryUsed / 1024.0 / 1024.0,
           [UIDevice currentDevice].memoryFree / 1024.0 / 1024.0,
           [UIDevice currentDevice].memoryActive / 1024.0 / 1024.0,
           [UIDevice currentDevice].memoryInactive / 1024.0 / 1024.0,
           [UIDevice currentDevice].memoryWired / 1024.0 / 1024.0,
           [UIDevice currentDevice].memoryPurgable / 1024.0 / 1024.0);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self log];
    });
}

- (void)addCell:(NSString *)title class:(NSString *)className {
    [self.titles addObject:title];
    [self.classNames addObject:className];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"YY"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"YY"];
    }
    cell.textLabel.text = _titles[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *className = self.classNames[indexPath.row];
    Class class = NSClassFromString(className);
    if (class) {
        UIViewController *ctrl = class.new;
        ctrl.title = _titles[indexPath.row];
        [self.navigationController pushViewController:ctrl animated:YES];
    }
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}


- (void)test{
    //    获取属性，以及类型，
    objc_property_t property = class_getProperty([WBStatus class], "rid");
    
    unsigned int num;
    objc_property_attribute_t *attr = property_copyAttributeList(property, &num);
    for (unsigned int i = 0; i < num; i++) {
        objc_property_attribute_t att = attr[i];
        fprintf(stdout, "name = %s , value = %s \n",att.name , att.value);
    }
    const char *chars = property_getAttributes(property);
    fprintf(stdout, "%s \n",chars);
}
/*
 name = T , value = @"NSString"
 name = & , value =
 name = N , value =
 name = V , value = _rid
 T@"NSString",&,N,V_rid
 */
/*
 属性类型  name值：T  value：
 编码类型  name值：C(copy) &(strong) W(weak) 空(assign) 等 value：无
 非/原子性 name值：空(atomic) N(Nonatomic)  value：无
 变量名称  name值：V  value：
 */
- (void)test1 {
    NSString *bananas = @"123.321abc137d efg/hij kl";
    NSString *separatorString = @"fg";
    BOOL result;
    
    NSScanner *aScanner = [NSScanner scannerWithString:bananas];
    
    //扫描字符串
    //扫描到指定字符串时停止，返回结果为指定字符串之前的字符串
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    NSString *container;
    result = [aScanner scanUpToString:separatorString intoString:&container];
    NSLog(@"扫描成功：%@", result?@"YES":@"NO");
    NSLog(@"扫描的返回结果：%@", container);
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    
    //扫描整数
    //将会接着上一次扫描结束的位置继续扫描
    NSLog(@"-------------------------------------1");
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    NSInteger anInteger;
    result = [aScanner scanInteger:&anInteger];
    NSLog(@"扫描成功：%@", result?@"YES":@"NO");
    NSLog(@"扫描的返回结果：%ld", anInteger);
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    
    //扫描整数
    //将扫描仪的位置置为首位置
    //扫描仪默认会接着上一次扫描结束的位置开始扫描，而不是重新从首位置开始
    //当扫描到一个不是整数的字符时将会停止扫描（如果开始扫描的位置不为整数，则会直接停止扫描）
    NSLog(@"-------------------------------------2");
    aScanner.scanLocation = 0;      //将扫描仪的位置置为首位置
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    NSInteger anInteger2;
    result = [aScanner scanInteger:&anInteger2];
    NSLog(@"扫描成功：%@", result?@"YES":@"NO");
    NSLog(@"扫描的返回结果：%ld", anInteger2);
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    
    //扫描浮点数
    //当扫描到一个不是整数的字符时将会停止扫描（如果开始扫描的位置不为整数，则会直接停止扫描）
    NSLog(@"-------------------------------------3");
    aScanner.scanLocation = 0;      //将扫描仪的位置置为首位置
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    float aFloat;
    result = [aScanner scanFloat:&aFloat];
    NSLog(@"扫描成功：%@", result?@"YES":@"NO");
    NSLog(@"扫描的返回结果：%f", aFloat);
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    
    NSLog(@"-------------------------------------4");
    NSLog(@"所扫描的字符串：%@", aScanner.string);
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    NSLog(@"是否扫描到末尾：%@", aScanner.isAtEnd?@"YES":@"NO");
    
    
    NSLog(@"-------------------------------------5");
    aScanner.scanLocation = 0;      //将扫描仪的位置置为首位置
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    NSString *str;
    NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];
    result = [aScanner scanUpToCharactersFromSet:characterSet intoString:&str];
    NSLog(@"扫描成功：%@", result?@"YES":@"NO");
    NSLog(@"扫描的返回结果：%@", str);
    NSLog(@"扫描仪所在的位置：%lu", aScanner.scanLocation);
    
    
}
- (void)test2{
    NSString * numStr = @"a 1 b 2 c 3 d 4 e 5 b 6 o";
    NSScanner * scanner = [NSScanner scannerWithString:numStr];
    NSCharacterSet * numSet = [NSCharacterSet decimalDigitCharacterSet];
    while ( NO == [scanner isAtEnd]) {
        if ([scanner scanUpToCharactersFromSet:numSet intoString:NULL]) {
            int num;
            if ([scanner scanInt:&num]) {
                NSLog(@"num=%d, %ld",num, scanner.scanLocation);
            }
        }
    }
    while ( NO == [scanner isAtEnd]) {
        NSString * value;
        if ([scanner scanString:@"b" intoString:&value]) {
            NSLog(@"value = %@, %ld",value, scanner.scanLocation);
        }
    }
    
}
-(void) test3{
    NSString* body = @"a 1 b 2 c 3 d 4 e 5 b 6 o";
    NSString* keyString = @"b";
    NSScanner * scanner = [NSScanner scannerWithString:body];
    [scanner setCaseSensitive:NO];
    NSString * value ;
    while (![scanner isAtEnd]){
        if ([scanner scanString:keyString intoString:&value]) {
            NSLog(@"1 value = %@",value);
            NSLog(@"1 location = %@",@(scanner.scanLocation));
        }else{
            NSLog(@"2 value = %@",value);
            scanner.scanLocation ++;
            NSLog(@"2 location = %@",@(scanner.scanLocation));
        }
    }
}

@end



