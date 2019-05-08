//
//  FFVideoDecoder.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/5.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFFrame.h"
#import "avformat.h"
#import "FFHeader.h"

@interface FFVideoDecoderModel : NSObject
@property(nonatomic,assign) AVCodecContext *codecContex;
@property(nonatomic,assign) NSTimeInterval timebase;
@property(nonatomic,assign) float fps;

/**
 * - video: the pixel format, the value corresponds to enum AVPixelFormat.
 * - audio: the sample format, the value corresponds to enum AVSampleFormat.
 */
@property(nonatomic,assign) int format;

@property(nonatomic,assign) int rotate;
@property(nonatomic,assign) float duration;
@property(nonatomic,assign) BOOL videoToolBoxEnable;
@end

@interface FFVideoDecoder : NSObject

+ (instancetype)decoderWithModel:(FFVideoDecoderModel*)model;

- (FFVideoFrame *)getFrameAsync;
- (FFVideoFrame *)topFrame;
- (void)putPacket:(AVPacket)packet;

- (int)bufferSize;
- (int)bufferCount;
- (double)bufferDuration;
- (BOOL)emtpy;
- (void)flush;
- (void)seek;
- (void)destroy;

- (void)startDecodeThread;
@property(nonatomic,strong) FFState* state;
@end



