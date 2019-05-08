//
//  FFFrame.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/4.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFFrame.h"

@implementation FFAudioFrame

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.type = FFFrameTypeAudio;
        self.length = 0;
    }
    
    return self;
}

- (NSInteger)length
{
	return self.samples.length;
}

- (void)dealloc
{
	self.samples = nil;
}

@end

@implementation FFVideoFrame

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.type = FFFrameTypeVideoYUV420;
    }
    
    return self;
}

@end

@implementation FFVideoFrameNV12

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.type = FFFrameTypeVideoNV12;
    }
    
    return self;
}

- (void)setPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    [self flush];
    _pixelBuffer = pixelBuffer;
}

- (void)flush
{
    if (_pixelBuffer)
    {
        CVPixelBufferRelease(_pixelBuffer);
        _pixelBuffer = NULL;
    }
}

- (void)dealloc
{
    [self flush];
}

@end

@interface FFFrame()
@end

@implementation FFFrame

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.enableReferenceCount = NO;
        self.referenceCount = 0;
		self.mutex = [[NSRecursiveLock alloc]init];
    }
    
    return self;
}

- (void)lock
{
    [self.mutex lock];

    if(!self.enableReferenceCount)
    {
        [self.mutex unlock];
        return;
    }

    self.referenceCount++;

    if(self.delegate && [self.delegate respondsToSelector:@selector(frameDidLock:)])
    {
        [self.delegate frameDidLock:self];
    }

    [self.mutex unlock];
}

- (void)unlock
{
    [self.mutex lock];

    if(!self.enableReferenceCount || self.referenceCount <= 0)
    {
        [self.mutex unlock];
        return;
    }

    self.referenceCount--;

    if(self.delegate && [self.delegate respondsToSelector:@selector(frameDidUnlock:)])
    {
        [self.delegate frameDidUnlock:self];
    }

    [self.mutex unlock];
}

- (void) clearAllLock
{
    [self.mutex lock];

    if(!self.enableReferenceCount || self.referenceCount <= 0)
    {
        [self.mutex unlock];
        return;
    }

    self.referenceCount = 0;

    if(self.delegate && [self.delegate respondsToSelector:@selector(frameDidUnlock:)])
    {
        [self.delegate frameDidUnlock:self];
    }

    [self.mutex unlock];
}

- (void) reset
{
    [self.mutex lock];

    self.position   = 0;
    self.duration   = 0;
    self.packetSize = 0;

    [self.mutex unlock];
}

@end
