//
//  FFFrame.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/4.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFHeader.h"
#import "avformat.h"
@class FFFrame;

@protocol FFFrameDelegate<NSObject>
@optional
- (void) frameDidLock:(FFFrame*)frame;
- (void) frameDidUnlock:(FFFrame*)frame;
@end

@interface FFFrame : NSObject
@property(nonatomic,assign) FFFrameType type;
@property(nonatomic,assign) float position;
@property(nonatomic,assign) float duration;
@property(nonatomic,assign) int packetSize;

@property(nonatomic,weak) id<FFFrameDelegate> delegate;
@property(nonatomic,assign) BOOL enableReferenceCount;
@property(nonatomic,assign) NSInteger referenceCount;

@property (nonatomic, strong) NSRecursiveLock *mutex;

- (void) lock;
- (void) unlock;
- (void) clearAllLock;
- (void) reset;
@end

@interface FFAudioFrame : FFFrame
@property(nonatomic,strong) NSData* samples;
@property(nonatomic,assign) NSInteger length;
@property(nonatomic,assign) NSInteger outputOffset;
@end

@interface FFVideoFrame : FFFrame
@property(nonatomic,strong) NSData* luma;
@property(nonatomic,strong) NSData* chromaB;
@property(nonatomic,strong) NSData* chromaR;

@property(nonatomic,assign) int width;
@property(nonatomic,assign) int height;

//video: the pixel format, the value corresponds to enum AVPixelFormat.
@property(nonatomic,assign) int src_format;
@property(nonatomic,assign) int dst_format;

@property(nonatomic,assign) FFRotationMode rotateMode;
@property(nonatomic,assign) BOOL keyframe;
@end

@interface FFVideoFrameNV12 : FFVideoFrame
@property(nonatomic,assign) CVPixelBufferRef pixelBuffer;
@end

