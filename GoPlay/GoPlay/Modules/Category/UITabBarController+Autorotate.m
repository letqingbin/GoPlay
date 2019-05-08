//
//  UITabBarController+Autorotate.m
//  GoPlay
//
//  Created by dKingbin on 2018/11/23.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "UITabBarController+Autorotate.h"

@implementation UITabBarController (Autorotate)

- (BOOL)shouldAutorotate
{
    return self.selectedViewController.shouldAutorotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return self.selectedViewController.supportedInterfaceOrientations;
}

@end
