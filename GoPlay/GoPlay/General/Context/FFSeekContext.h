//
//  FFSeekContext.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/25.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFSeekContext : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)shareContext;

@property(nonatomic,assign) float seekToTime;
@property(nonatomic,assign) double seek_start_time;

@property(nonatomic,assign) int drop_vframe_count;
@property(nonatomic,assign) int drop_aframe_count;

@property(nonatomic,assign) int video_seek_completed;
@property(nonatomic,assign) int audio_seek_completed;

@property(nonatomic,assign) float audio_seek_start_time;
@property(nonatomic,assign) float video_seek_start_time;

@property(nonatomic,assign) int drop_vPacket_count;
@property(nonatomic,assign) int drop_aPacket_count;
@end
