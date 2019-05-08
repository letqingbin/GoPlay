//
//  FFAudioDecoder.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/4.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFFrame.h"
#import "avformat.h"

@interface FFAudioDecoderModel : NSObject
@property(nonatomic,assign) AVCodecContext *codecContex;
@property(nonatomic,assign) NSTimeInterval timebase;
@property(nonatomic,assign) int sampleRate;
@property(nonatomic,assign) UInt32 numOutputChannels;
@property(nonatomic,assign) int format;

@property(nonatomic,assign) float duration;
@end

@interface FFAudioDecoder : NSObject

+ (instancetype)decoderWithModel:(FFAudioDecoderModel*)model;

- (FFAudioFrame *)getFrameAsync;
- (int)putPacket:(AVPacket)packet;

- (int) bufferSize;
- (int) bufferCount;
- (double) bufferDuration;
- (BOOL)emtpy;
- (void)flush;
- (void)destroy;
- (void)startDecodeThread;
- (void)seek;

@property(nonatomic,strong) FFState* state;
@end
