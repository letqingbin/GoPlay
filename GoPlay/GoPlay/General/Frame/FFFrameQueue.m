//
//  FFFrameQueue.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/4.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFFrameQueue.h"

@interface FFFrameQueue()
@property (nonatomic, strong) NSCondition * condition;
@property (nonatomic, strong) NSMutableArray <__kindof FFFrame *> * frames;

@property (nonatomic, assign) BOOL destoryToken;
@end

@implementation FFFrameQueue

+ (instancetype)queue
{
    return [[self alloc]init];
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.frames = [NSMutableArray array];
        self.condition = [[NSCondition alloc]init];
    }
    
    return self;
}

- (void)putFrame:(__kindof FFFrame *)frame
{
    if (!frame) return;
    [self.condition lock];
    
    if (self.destoryToken)
    {
        [self.condition unlock];
        return;
    }
    
    [self.frames addObject:frame];
    self.duration += frame.duration;
	self.packetSize += frame.packetSize;
    [self.condition signal];
    [self.condition unlock];
}

- (void)putSortFrame:(__kindof FFFrame *)frame
{
    if (!frame) return;
    [self.condition lock];
    if (self.destoryToken)
    {
        [self.condition unlock];
        return;
    }
    
    BOOL added = NO;
    if (self.frames.count > 0)
    {
        for (int i = (int)self.frames.count - 1; i >= 0; i--)
        {
            FFFrame * obj = [self.frames objectAtIndex:i];
            if (frame.position > obj.position)
            {
                [self.frames insertObject:frame atIndex:i + 1];
                added = YES;
                break;
            }
        }
    }
    if (!added)
    {
		[self.frames insertObject:frame atIndex:0];
    }
    
    self.duration += frame.duration;
	self.packetSize += frame.packetSize;
    [self.condition signal];
    [self.condition unlock];
}

- (__kindof FFFrame *)getFrameSync
{
    [self.condition lock];
    while (self.frames.count <= 0)
    {
        if (self.destoryToken)
        {
            [self.condition unlock];
            return nil;
        }
        [self.condition wait];
    }
    
    FFFrame * frame = self.frames.firstObject;
    [self.frames removeObjectAtIndex:0];
    self.duration -= frame.duration;
    if (self.duration < 0 )
    {
        self.duration = 0;
    }

	self.packetSize -= frame.packetSize;
	if(self.packetSize < 0)
	{
		self.packetSize = 0;
	}

    [self.condition unlock];
    return frame;
}

- (__kindof FFFrame *)getFrameAsync
{
    [self.condition lock];
    if (self.destoryToken || self.frames.count <= 0)
    {
        [self.condition unlock];
        return nil;
    }

    FFFrame * frame = self.frames.firstObject;
    [self.frames removeObjectAtIndex:0];
    self.duration -= frame.duration;
    if (self.duration < 0 )
    {
        self.duration = 0;
    }

	self.packetSize -= frame.packetSize;
	if(self.packetSize < 0)
	{
		self.packetSize = 0;
	}
    
    [self.condition unlock];
    return frame;
}

- (__kindof FFFrame *)topFrame
{
	[self.condition lock];
	if (self.destoryToken || self.frames.count <= 0)
	{
		[self.condition unlock];
		return nil;
	}

	FFFrame * frame = self.frames.firstObject;
	[self.condition unlock];
	return frame;
}

- (NSInteger)count
{
	[self.condition lock];
	NSInteger count = self.frames.count;
	[self.condition unlock];

    return count;
}

- (void)flush
{
    [self.condition lock];
    
    [self.frames removeAllObjects];
    self.duration = 0;
	self.packetSize = 0;
    [self.condition unlock];
}

- (void)destroy
{
    [self flush];
    [self.condition lock];
    self.destoryToken = YES;
    [self.condition broadcast];
    [self.condition unlock];
}

- (void)dealloc
{
	LOG_DEBUG(@"%@ release...",[self class]);
}

@end
