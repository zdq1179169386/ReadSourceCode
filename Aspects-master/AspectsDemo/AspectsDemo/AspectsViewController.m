//
//  AspectsViewController.m
//  AspectsDemo
//
//  Created by Peter Steinberger on 05/05/14.
//  Copyright (c) 2014 PSPDFKit GmbH. All rights reserved.
//

#import "AspectsViewController.h"
#import "Aspects.h"
#import "Person.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation AspectsViewController
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.view.backgroundColor = [UIColor blueColor];
    
}
- (void)viewDidLoad
{
    [super viewDidLoad];
//    https://wereadteam.github.io/2016/06/30/Aspects/
//    hook 类方法,因为类方法在元类里面，x所以先获取元类，然后从元类的方法列表中找
    
    Person * p = [Person new];
    NSLog(@"1 = %p,2 = %p",[p class],[Person class]);
//    获取实例对象的p 的类
    NSLog(@"1 = %@,2 = %p",object_getClass(p),object_getClass(p));
//    获取Person 的元类
    NSLog(@"1 = %@,2 = %p",object_getClass([p class]), object_getClass([p class]));
//    获取根元类
    NSLog(@"p = %@",object_getClass(object_getClass([Person class])));
    NSLog(@"NSObject = %p",[NSObject class]);
    NSLog(@"NSObject = %p",object_getClass([NSObject class]));
    NSLog(@"p = %p",object_getClass(object_getClass([Person class])));

    
//    [catMetal aspect_hookSelector:@selector(printf) withOptions:(AspectPositionBefore) usingBlock:^(id<AspectInfo> info){
//        NSLog(@"qwe");
//    } error:NULL];
    
    [Person aspect_hookSelector:@selector(printf) withOptions:(AspectPositionBefore) usingBlock:^(id<AspectInfo> info){
        NSLog(@"qwe");
    } error:NULL];
    
    [Person printf];
}

- (IBAction)buttonPressed:(id)sender {
    UIViewController *testController = [[UIImagePickerController alloc] init];

    testController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:testController animated:YES completion:NULL];

    // We are interested in being notified when the controller is being dismissed.
    [testController aspect_hookSelector:@selector(viewWillDisappear:) withOptions:0 usingBlock:^(id<AspectInfo> info, BOOL animated) {
        UIViewController *controller = [info instance];
        if (controller.isBeingDismissed || controller.isMovingFromParentViewController) {
            [[[UIAlertView alloc] initWithTitle:@"Popped" message:@"Hello from Aspects" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Ok", nil] show];
        }
    } error:NULL];

    // Hooking dealloc is delicate, only AspectPositionBefore will work here.
    [testController aspect_hookSelector:NSSelectorFromString(@"dealloc") withOptions:AspectPositionBefore usingBlock:^(id<AspectInfo> info) {
        NSLog(@"Controller is about to be deallocated: %@", [info instance]);
    } error:NULL];
    
    
}

@end
