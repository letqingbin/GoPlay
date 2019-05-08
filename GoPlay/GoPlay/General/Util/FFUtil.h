//
//  FFUtil.h
//  GoPlay
//
//  Created by dKingbin on 2018/9/28.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avformat.h"

@interface FFUtil : NSObject
+ (BOOL)ff_is_b_frame:(const AVPacket*)packet;
@end
