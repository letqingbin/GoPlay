//
//  FFFrameQueue.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/4.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFFrame.h"

@interface FFFrameQueue : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype) queue;

- (void)putFrame:(__kindof FFFrame *)frame;
- (void)putSortFrame:(__kindof FFFrame *)frame;
- (__kindof FFFrame *)getFrameSync;
- (__kindof FFFrame *)getFrameAsync;
- (__kindof FFFrame *)topFrame;

- (void)flush;
- (void)destroy;
- (NSInteger)count;

@property(nonatomic, assign) float duration;
@property(nonatomic, assign) int packetSize;

@end
