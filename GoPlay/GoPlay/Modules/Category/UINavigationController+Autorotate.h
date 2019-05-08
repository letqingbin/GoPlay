//
//  UINavigationController+Autorotate.h
//  GoPlay
//
//  Created by dKingbin on 2018/11/23.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UINavigationController (Autorotate)
- (BOOL)shouldAutorotate;
- (UIInterfaceOrientationMask)supportedInterfaceOrientations;
@end
