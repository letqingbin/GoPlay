//
//  FFMovie.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFMovie.h"
#import "FFHeader.h"
#import "FFVertexMatrix.h"

#import "FFGLProgramYUV420.h"
#import "FFGLProgramNV12.h"

#import "FFFramebuffer.h"
#import "FFFramebufferPool.h"
#import "FFGLContext.h"

@interface FFMovie()
@property(nonatomic,strong) FFGLProgram* program;
@property(nonatomic,assign) GLuint framebufferId;
@property(nonatomic,assign) GLuint renderbufferId;
@property(nonatomic,assign) CGSize framebufferSize;
@end

@implementation FFMovie

- (instancetype)init
{
	self = [super init];

	if(self)
	{
		self.mode = FFRotationMode_R0;
	}

	return self;
}

- (void)render:(FFVideoFrame*)frame
{
	runAsync(^{
		[[FFGLContext shareInstance] useCurrentContext];

        if(ff_swap_wh(frame.rotateMode))
        {
            self.framebufferSize = CGSizeMake(frame.height, frame.width);
        }
        else
        {
            self.framebufferSize = CGSizeMake(frame.width, frame.height);
        }
		
		self.outputFramebuffer = [[FFFramebufferPool shareInstance] getUnuseFramebufferBySize:self.framebufferSize];
		[self.outputFramebuffer activateFramebuffer];

		glClearColor(0.0, 0.0, 0.0, 1.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		if(!self.program)
		{
			if(frame.type == FFFrameTypeVideoYUV420)
			{
				self.program = [FFGLProgramYUV420 program];
			}
			else if(frame.type == FFFrameTypeVideoNV12)
			{
				self.program = [FFGLProgramNV12 program];
			}
		}

		[self.program use];
		[self.program render:frame];

        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

		//frame.position
		[self infromTargetsAboutNewFrameAtTime:frame.position];
	});
}

- (void)infromTargetsAboutNewFrameAtTime:(NSTimeInterval)time
{
	for(id<FFInputProtocol> target in self.targets)
	{
		NSInteger indexOfObject = [self.targets indexOfObject:target];
		NSInteger index = [[self.targetIndices objectAtIndex:indexOfObject] integerValue];
		[target setInputRotate:self.mode atIndex:index];
		[target setInputSize:self.framebufferSize atIndex:index];
		[target setInputFramebuffer:self.outputFramebuffer atIndex:index];
	}

	for(id<FFInputProtocol> target in self.targets)
	{
		NSInteger indexOfObject = [self.targets indexOfObject:target];
		NSInteger index = [[self.targetIndices objectAtIndex:indexOfObject] integerValue];
		[target newFrameReadyAtTime:time atIndex:index];
	}
}

- (void)clearRenderBuffers
{
	[[FFGLContext shareInstance] useCurrentContext];

	if(self.renderbufferId)
	{
		glDeleteRenderbuffers(1, &_renderbufferId);
		_renderbufferId = 0;
	}

	if(self.framebufferId)
	{
		glDeleteFramebuffers(1, &_framebufferId);
		_framebufferId = 0;
	}
}

- (void)dealloc
{
	[self clearRenderBuffers];
}

@end
