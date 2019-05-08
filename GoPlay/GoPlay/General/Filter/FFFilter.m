//
//  FFFilter.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFFilter.h"

#import "FFHeader.h"
#import "FFFramebuffer.h"
#import "FFFramebufferPool.h"
#import "FFGLProgram.h"
#import "FFGLContext.h"
#import "FFVertexMatrix.h"
#import "GLSL.h"

@interface FFFilter()
@end

@implementation FFFilter

- (instancetype)init
{
	self = [super init];

	if(self)
	{
		[self initParams];
	}

	return self;
}

- (void)initParams
{
	[[FFGLContext shareInstance] useCurrentContext];
	
	[self didUpdateProgram];

	[self didBindProgram];
	[self didUpdateParameter];
}

#pragma mark -- overload
- (void)didUpdateProgram
{
	self.program = [[FFGLProgram alloc]initWithVertexShader:kFFPassthroughVertexShaderString
											 fragmentShader:kFFPassthroughFragmentShaderString];
}

- (void)didBindProgram
{
	self.positionId = [self.program bindAttribute:@"position"];
	self.inputTextureCoordinateId = [self.program bindAttribute:@"inputTextureCoordinate"];
	self.inputImageTextureId = [self.program bindUniform:@"inputImageTexture"];
}

- (void)didUpdateParameter
{
	glEnableVertexAttribArray(self.inputTextureCoordinateId);
	glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, opengl_rotate_matrix(FFRotationMode_R0));

	glEnableVertexAttribArray(self.positionId);
	glVertexAttribPointer(self.positionId, 2, GL_FLOAT, GL_FALSE, 0, gl_vertex_matrix());
}

- (void)didUpdateFilter
{
	//need to update every times
	glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, opengl_rotate_matrix(self.rotationMode));
	glVertexAttribPointer(self.positionId, 2, GL_FLOAT, GL_FALSE, 0, gl_vertex_matrix());
}

- (void)didDrawCall
{
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)didEndUpdateFilter
{}

- (void)render
{
	runAsync(^{
		[[FFGLContext shareInstance] useCurrentContext];

		self.outputFramebuffer = [[FFFramebufferPool shareInstance] getUnuseFramebufferBySize:self.framebufferSize];
		[self.outputFramebuffer activateFramebuffer];

		glClearColor(0.0, 0.0, 0.0, 1.0);
		glClear(GL_COLOR_BUFFER_BIT);

		[self.program use];

		//overload
		[self didUpdateFilter];

		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, [self.inputFramebuffer texture]);
		glUniform1i(self.inputImageTextureId, 4);

		//overload
		[self didDrawCall];

		//overload
		[self didEndUpdateFilter];
	});
}

- (void)infromTargetsAboutNewFrameAtTime:(NSTimeInterval)time
{
	runAsync(^{
		for(id<FFInputProtocol> target in self.targets)
		{
			NSInteger indexOfObject = [self.targets indexOfObject:target];
			NSInteger index = [[self.targetIndices objectAtIndex:indexOfObject] integerValue];
			[target setInputSize:self.framebufferSize atIndex:index];
			[target setInputFramebuffer:self.outputFramebuffer atIndex:index];
		}

		for(id<FFInputProtocol> target in self.targets)
		{
			NSInteger indexOfObject = [self.targets indexOfObject:target];
			NSInteger index = [[self.targetIndices objectAtIndex:indexOfObject] integerValue];
			[target newFrameReadyAtTime:time atIndex:index];
		}
	});
}

#pragma mark -- FFInputProtocol
- (void)setInputFramebuffer:(FFFramebuffer*)framebuffer atIndex:(NSInteger)index
{
	self.inputFramebuffer = framebuffer;
}

- (void)setInputSize:(CGSize)size atIndex:(NSInteger)index
{
	if(ff_swap_wh(self.rotationMode))
	{
		int width  = size.width;
		int height = size.height;

		CGSize rotateSize = CGSizeMake(height, width);
		self.framebufferSize = rotateSize;
	}
	else
	{
		self.framebufferSize = size;
	}
}

- (void)setInputRotate:(FFRotationMode)mode atIndex:(NSInteger)index
{
	self.rotationMode = mode;
}

- (void)newFrameReadyAtTime:(NSTimeInterval)time atIndex:(NSInteger)index
{
	[self render];
	[self infromTargetsAboutNewFrameAtTime:time];
	[self.inputFramebuffer unlock];
}

- (NSInteger)nextAvailableTextureIndex
{
	return 0;
}

- (void)endProcess
{
	for(id<FFInputProtocol> target in self.targets)
	{
		[target endProcess];
	}
}

@end
