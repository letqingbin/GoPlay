//
//  FFGLContext.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFGLContext.h"
#import "FFQueueContext.h"

@interface FFGLContext()
@property(nonatomic,strong) EAGLContext* context;
@property(nonatomic,assign) CVOpenGLESTextureCacheRef videoTextureCache;
@end

@implementation FFGLContext

+ (instancetype)shareInstance
{
	static FFGLContext* obj;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		obj = [[self alloc]init];
		obj.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
		NSAssert(obj.context, @"failed to create EAGLContext");
	});

	return obj;
}

- (void)useCurrentContext
{
	if([EAGLContext currentContext] != self.context)
	{
		[EAGLContext setCurrentContext:self.context];
	}
}

- (EAGLContext*)context
{
	return _context;
}

- (CVOpenGLESTextureCacheRef)videoTextureCache
{
	if(!_videoTextureCache)
	{
		 CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
													 NULL,
													 [[FFGLContext shareInstance] context],
													 NULL,
													 &_videoTextureCache);
		assert(err == kCVReturnSuccess);
	}

	return _videoTextureCache;
}

@end
