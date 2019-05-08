//
//  FFUtil.m
//  GoPlay
//
//  Created by dKingbin on 2018/9/28.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFUtil.h"
#include "FFFrameUtil.hpp"

@interface FFUtil()
@end

@implementation FFUtil

+ (BOOL)ff_is_b_frame:(const AVPacket*)packet
{
	return ffstl::FFFrameUtil::ff_is_b_frame(packet);
}

@end
