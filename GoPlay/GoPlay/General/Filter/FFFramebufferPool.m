//
//  FFFramebufferPool.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFFramebufferPool.h"

@interface FFFramebufferPool()
@property (nonatomic, strong) NSRecursiveLock * lock;
@property (nonatomic, strong) NSMutableDictionary *unuseFrames;
@property (nonatomic, strong) NSMutableDictionary *usedFrames;

@property (nonatomic, assign) CGSize size;
@end

@implementation FFFramebufferPool

+ (instancetype)shareInstance
{
	static FFFramebufferPool* obj = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		obj = [[self alloc]init];
	});

	return obj;
}

- (instancetype)init
{
	self = [super init];

	if(self)
	{
		self.lock = [[NSRecursiveLock alloc] init];
		self.unuseFrames = [NSMutableDictionary dictionary];
		self.usedFrames  = [NSMutableDictionary dictionary];
	}

	return self;
}

+ (NSString*)hashKeyBySize:(CGSize)size options:(FFGPUTextureOptions)options
{
	NSString* key = nil;

	key = [NSString stringWithFormat:@"%.1fx%.1f-%d:%d:%d:%d:%d:%d:%d",
		   size.width,
		   size.height,
		   options.minFilter,
		   options.magFilter,
		   options.wrapS,
		   options.wrapT,
		   options.internalFormat,
		   options.format,
		   options.type];

	return key;
}

- (__kindof FFFramebuffer *)getUnuseFramebufferBySize:(CGSize)size
{
	NSString* key = [FFFramebufferPool hashKeyBySize:size
											 options:[FFFramebuffer defaultTextureOptions]];
	self.size = size;
	return [self getUnuseFramebufferByKey:key];
}

- (__kindof FFFramebuffer *)getUnuseFramebufferByKey:(NSString*)key
{
	[self.lock lock];
	FFFramebuffer * framebuffer;

	NSMutableArray* unuseArray = self.unuseFrames[key];

	if(unuseArray.count > 0)
	{
		framebuffer = unuseArray[0];
	}

	if(framebuffer)
	{
		framebuffer.enableReferenceCount = YES;
		framebuffer.delegate = self;
		[framebuffer lock];
	}
	else
	{
		framebuffer = [[FFFramebuffer alloc]initWithSize:self.size];
		framebuffer.enableReferenceCount = YES;
		framebuffer.delegate = self;
		[framebuffer lock];
	}

	[self.lock unlock];
	return framebuffer;
}

- (void)unlockFramebuffer:(FFFramebuffer*)framebuffer
{
	if (!framebuffer) return;
	[self.lock lock];
	[framebuffer unlock];
	[self.lock unlock];
}

- (void)flush
{
	[self.lock lock];

	[self.usedFrames enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, FFFramebuffer*  _Nonnull obj, BOOL * _Nonnull stop) {
		[obj clearAllLock];
	}];

	[self.lock unlock];
}

#pragma mark -- FFFramebufferDelegate
- (void) framebufferDidUnlock:(FFFramebuffer*)framebuffer
{
	[self.lock lock];

	if(framebuffer.referenceCount <= 0)
	{
		NSString* key = [FFFramebufferPool hashKeyBySize:framebuffer.size options:framebuffer.options];
		NSMutableArray* usedArray = self.usedFrames[key];
		NSMutableArray* unuseArray = self.unuseFrames[key];

		if(unuseArray.count <= 0)
		{
			unuseArray = [NSMutableArray array];
		}

		if(![unuseArray containsObject:framebuffer])
		{
			[unuseArray addObject:framebuffer];
		}

		if(usedArray.count > 0 && [usedArray containsObject:framebuffer])
		{
			[usedArray removeObject:framebuffer];
		}

		self.usedFrames[key] = usedArray;
		self.unuseFrames[key] = unuseArray;
	}

	[self.lock unlock];
}

- (void) framebufferDidLock:(FFFramebuffer*)framebuffer
{
	[self.lock lock];

	NSString* key = [FFFramebufferPool hashKeyBySize:framebuffer.size options:framebuffer.options];
	NSMutableArray* usedArray = self.usedFrames[key];
	NSMutableArray* unuseArray = self.unuseFrames[key];

	if(unuseArray.count > 0 && [unuseArray containsObject:framebuffer])
	{
		[unuseArray removeObject:framebuffer];
	}

	if(usedArray.count <= 0)
	{
		usedArray = [NSMutableArray array];
	}

	if(![usedArray containsObject:framebuffer])
	{
		[usedArray addObject:framebuffer];
	}

	self.usedFrames[key] = usedArray;
	self.unuseFrames[key] = unuseArray;

	[self.lock unlock];
}

@end
