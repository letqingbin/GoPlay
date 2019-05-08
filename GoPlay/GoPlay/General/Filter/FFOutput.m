//
//  FFOutput.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFOutput.h"
#import "FFFilter.h"
#import "ReactiveCocoa.h"
#import "FFFramebufferPool.h"
#import "FFQueueContext.h"


@interface FFOutput()
@property(nonatomic,strong) dispatch_queue_t queue;
@end

@implementation FFOutput

- (instancetype)init
{
	self = [super init];

	if(self)
	{}

	return self;
}

- (void) addTarget:(id<FFInputProtocol>)target
{
	runAsync(^{
		NSInteger index = [target nextAvailableTextureIndex];
		[self addTarget:target atIndex:index];
	});
}

- (void) addTarget:(id<FFInputProtocol>)target atIndex:(NSInteger)index
{
	runAsync(^{
		if([self.targets containsObject:target]) return;
		[target setInputFramebuffer:self.outputFramebuffer atIndex:index];
		[self.targets addObject:target];
		[self.targetIndices addObject:@(index)];
	});
}

- (void) removeTarget:(id<FFInputProtocol>)target
{
	runAsync(^{
		if(![self.targets containsObject:target]) return;
		NSInteger indexOfObject = [self.targets indexOfObject:target];
		NSInteger index = [[self.targetIndices objectAtIndex:indexOfObject] integerValue];
		[target setInputSize:CGSizeZero atIndex:index];
		[self.targets removeObject:target];
		[self.targetIndices removeObjectAtIndex:index];
		[target endProcess];
	});
}

- (void) removeAllTargets
{
	runAsync(^{
		for(id<FFInputProtocol> target in self.targets)
		{
			NSInteger indexOfObject = [self.targets indexOfObject:target];
			NSInteger index = [[self.targetIndices objectAtIndex:indexOfObject] integerValue];
			[target setInputSize:CGSizeZero atIndex:index];
			[target endProcess];
		}

		[self.targets removeAllObjects];
		[self.targetIndices removeAllObjects];
	});
}

- (NSMutableArray *)targets
{
	if(!_targets)
	{
		_targets = [NSMutableArray array];
	}

	return _targets;
}

- (NSMutableArray *)targetIndices
{
	if(!_targetIndices)
	{
		_targetIndices = [NSMutableArray array];
	}

	return _targetIndices;
}

@end
