//
//  FFSeekContext.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/25.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFSeekContext.h"

@interface FFSeekContext()
@end

@implementation FFSeekContext

+ (instancetype)shareContext
{
    static FFSeekContext* obj;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        obj = [[self alloc]init];
    });
    
    return obj;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.video_seek_completed = 0;
        self.audio_seek_completed = 0;
    }
    
    return self;
}

@end
