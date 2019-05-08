//
//  FFAlphaBendFilter.m
//  GoPlay
//
//  Created by dKingbin on 2019/5/8.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import "FFAlphaBendFilter.h"
#import "FFGLContext.h"
#import "FFFramebuffer.h"
#import "FFFramebufferPool.h"

#import "FFHeader.h"
#import "FFVertexMatrix.h"
#import "FFGLProgram.h"
#import "GLSL.h"

#import <GLKit/GLKit.h>

@interface FFAlphaBendFilter()
@property(nonatomic,strong) FFFramebuffer* inputFramebuffer2;

@property(nonatomic,assign) GLuint inputTextureCoordinateId2;
@property(nonatomic,assign) GLuint inputImageTextureId2;
@property(nonatomic,assign) GLuint mixId;
@end

@implementation FFAlphaBendFilter

- (instancetype)init
{
	self = [super init];
	if(self)
	{
		self.mix = 0.5;
	}

	return self;
}

#pragma mark -- didUpdateProgram
- (void)didUpdateProgram
{
	self.program = [[FFGLProgram alloc] initWithVertexShader:kFFTwoInputTextureVertexShaderString
											  fragmentShader:kFFAlphaBlendFragmentShaderString];
}

- (void)setMix:(float)mix
{
	_mix = mix;
}

#pragma mark -- render
- (void)render
{
	runAsync(^{
		[[FFGLContext shareInstance] useCurrentContext];

		self.outputFramebuffer = [[FFFramebufferPool shareInstance] getUnuseFramebufferBySize:self.framebufferSize];
		[self.outputFramebuffer activateFramebuffer];

		glClearColor(0.0, 0.0, 0.0, 1.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		[self.program use];

		//overload
		[self didUpdateFilter];

		glActiveTexture(GL_TEXTURE4);
		glBindTexture(GL_TEXTURE_2D, [self.inputFramebuffer texture]);
		glUniform1i(self.inputImageTextureId, 4);

		glActiveTexture(GL_TEXTURE5);
		glBindTexture(GL_TEXTURE_2D, [self.inputFramebuffer2 texture]);
		glUniform1i(self.inputImageTextureId2, 5);

		//overload
		[self didDrawCall];

		//overload
		[self didEndUpdateFilter];
	});
}

#pragma mark -- didBindProgram
- (void)didBindProgram
{
	[super didBindProgram];

	self.inputTextureCoordinateId2 = [self.program bindAttribute:@"inputTextureCoordinate2"];
	self.inputImageTextureId2 = [self.program bindUniform:@"inputImageTexture2"];
	self.mixId = [self.program bindUniform:@"mixturePercent"];
}

#pragma mark -- didUpdateParameter
- (void)didUpdateParameter
{
	[super didUpdateParameter];

	glEnableVertexAttribArray(self.inputTextureCoordinateId2);
	glVertexAttribPointer(self.inputTextureCoordinateId2, 2, GL_FLOAT, GL_FALSE, 0, opengl_rotate_matrix(FFRotationMode_R0));
}

#pragma mark -- didUpdateFilter
- (void)didUpdateFilter
{
	//need to update every times
	glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, opengl_rotate_matrix(self.rotationMode));
	glVertexAttribPointer(self.inputTextureCoordinateId2, 2, GL_FLOAT, GL_FALSE, 0, opengl_rotate_matrix(FFRotationMode_R0));
	glVertexAttribPointer(self.positionId, 2, GL_FLOAT, GL_FALSE, 0, gl_vertex_matrix());

	glUniform1f(self.mixId, self.mix);
}

#pragma mark -- FFInputProtocol
- (void)setInputFramebuffer:(FFFramebuffer *)framebuffer atIndex:(NSInteger)index
{
	if(index == 0)
	{
		self.inputFramebuffer = framebuffer;
	}
	else
	{
		self.inputFramebuffer2 = framebuffer;
	}
}

- (void)setInputSize:(CGSize)size atIndex:(NSInteger)index
{
	self.framebufferSize = size;
}

@end
