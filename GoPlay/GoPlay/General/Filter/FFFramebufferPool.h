//
//  FFFramebufferPool.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFFramebuffer.h"

@interface FFFramebufferPool : NSObject<FFFramebufferDelegate>

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)shareInstance;

+ (NSString*)hashKeyBySize:(CGSize)size options:(FFGPUTextureOptions)options;
- (__kindof FFFramebuffer *)getUnuseFramebufferBySize:(CGSize)size;
- (__kindof FFFramebuffer *)getUnuseFramebufferByKey:(NSString*)key;

- (void)unlockFramebuffer:(FFFramebuffer*)framebuffer;

- (void)flush;

@end
