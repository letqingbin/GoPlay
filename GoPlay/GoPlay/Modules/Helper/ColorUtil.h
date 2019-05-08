//
//  ColorUtil
//  Line
//
//  Created by dKingbin on 2018/6/20.
//  Copyright © 2018年 dKingbin. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface ColorUtil : NSObject
/**
 *  从色值中生成颜色
 *
 *  @param color 色值 #909090 或者 0X909090
 *
 *  @return UIColor对象
 */
+ (UIColor *)colorWithHexString:(NSString *)color;

@end
