//
//  FFDecoder.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFHeader.h"

@class FFVideoDecoder;
@class FFAudioDecoder;
@class FFMediaInfoModel;

@interface FFDecoder : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithContentURL:(NSString *)contentURL
						   channel:(UInt32)numOutputChannels
						sampleRate:(Float64)sampleRate;

- (void)seekToTimeByRatio:(float)ratio;
- (void)seekToTimeByRatio:(float)ratio completeHandler:(void (^)(BOOL finished))completeHandler;
- (void)seekToTime:(NSTimeInterval)time;
- (void)seekToTime:(NSTimeInterval)time completeHandler:(void (^)(BOOL finished))completeHandler;

- (void)startDecoder;
- (void)pause;
- (void)destroy;
- (BOOL)isBufferEmtpy;
- (BOOL)isEndOfFile;

@property(nonatomic,assign) BOOL videoEnable;
@property(nonatomic,assign) BOOL audioEnable;

@property(nonatomic,strong) FFVideoDecoder* videoDecoder;
@property(nonatomic,strong) FFAudioDecoder* audioDecoder;
@property(nonatomic,strong) FFState* state;
@property(nonatomic,assign) float duration;

//starttime
@property(nonatomic,assign) float startTime;

//timeout
@property(nonatomic,assign) double interrupt_timeout;

@property(nonatomic,copy) void(^didErrorCallback)(void);
@property(nonatomic,copy) void(^didInterruptCallback)(void);
@end
