//
//  ColorUtil
//  GoPlay
//
//  Created by dKingbin on 2018/6/20.
//  Copyright © 2018年 dKingbin. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ColorUtil : NSObject
/**
 *
 *  @param color #909090 OR 0X909090
 *
 *  @return UIColor
 */
+ (UIColor *)colorWithHexString:(NSString *)color;

@end
