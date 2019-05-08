//
//  FFPacketQueue.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/5.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avformat.h"

@interface FFPacketQueue : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)packetQueueWithTimebase:(NSTimeInterval)timebase;

- (void)putPacket:(AVPacket)packet duration:(NSTimeInterval)duration;
- (AVPacket)getPacketSync;
- (AVPacket)getPacketAsync;

- (void)flush;
- (void)destroy;
- (NSInteger)count;

@property(nonatomic,assign) double duration;
@property(nonatomic,assign) int size;
@property(nonatomic,strong,readonly)NSMutableArray<NSValue *>* packets;
@end
