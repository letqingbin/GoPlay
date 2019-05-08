//
//  UINavigationController+Autorotate.m
//  GoPlay
//
//  Created by dKingbin on 2018/11/23.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "UINavigationController+Autorotate.h"

@implementation UINavigationController (Autorotate)

- (BOOL)shouldAutorotate
{
    return self.topViewController.shouldAutorotate;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return self.topViewController.supportedInterfaceOrientations;
}

@end
