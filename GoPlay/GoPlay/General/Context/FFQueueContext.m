//
//  FFQueueContext.m
//  GoPlay
//
//  Created by dKingbin on 2018/12/27.
//  Copyright © 2018 dKingbin. All rights reserved.
//

#import "FFQueueContext.h"
#import "ReactiveCocoa.h"

static const void* const kFFQueueContextQueueSpecificKey = &kFFQueueContextQueueSpecificKey;

void runSync(void (^block)(void))
{
	if(block == nil) return;

	dispatch_queue_t queue = [[FFQueueContext shareInstance] sharedContextQueue];
	if(dispatch_get_specific(kFFQueueContextQueueSpecificKey))
	{
		block();
	}
	else
	{
		dispatch_sync(queue, block);
	}
}

void runAsync(void (^block)(void))
{
	if(block == nil) return;

	dispatch_queue_t queue = [[FFQueueContext shareInstance] sharedContextQueue];
	if(dispatch_get_specific(kFFQueueContextQueueSpecificKey))
	{
		block();
	}
	else
	{
		dispatch_async(queue, block);
	}
}

void runSyncOnMainQueue(void (^block)(void))
{
	if(block == nil) return;

	if([NSThread isMainThread])
	{
		block();
	}
	else
	{
		dispatch_queue_t queue = dispatch_get_main_queue();
		dispatch_sync(queue, block);
	}
}

@interface FFQueueContext()
@property(nonatomic,strong) dispatch_queue_t queue;
@end

@implementation FFQueueContext

+(instancetype)shareInstance
{
	static dispatch_once_t onceToken;
	static FFQueueContext* obj = nil;
	dispatch_once(&onceToken, ^{
		obj = [[FFQueueContext alloc]init];
	});

	return obj;
}

- (instancetype)init
{
	self = [super init];

	if(self)
	{
		self.queue = dispatch_queue_create( "com.ffqueuecontext.queue", DISPATCH_QUEUE_SERIAL);
		dispatch_queue_set_specific(self.queue, kFFQueueContextQueueSpecificKey, (__bridge void *)self, NULL);
	}

	return self;
}

-(dispatch_queue_t)sharedContextQueue
{
	return self.queue;
}

@end
