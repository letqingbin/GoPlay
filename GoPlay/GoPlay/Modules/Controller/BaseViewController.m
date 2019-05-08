//
//  BaseViewController.m
//  GoPlay
//
//  Created by dKingbin on 2018/12/2.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "BaseViewController.h"
#import "FFHeader.h"

#import "UITabBarController+Autorotate.h"
#import "UINavigationController+Autorotate.h"

@interface BaseViewController ()

@end

@implementation BaseViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
	LOG_DEBUG(@"enter -- %@",[self class]);
}

-(UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

- (void)dealloc
{
	LOG_DEBUG(@"%@ release...",[self class]);
}

@end
