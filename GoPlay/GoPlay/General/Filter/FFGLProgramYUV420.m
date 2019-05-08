//
//  FFGLProgramYUV420.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFGLProgramYUV420.h"
#import <GLKit/GLKit.h>

#import "FFHeader.h"
#import "FFVertexMatrix.h"
#import "FFColorConversionHeader.h"
#import "GLSL.h"

@interface FFGLProgramYUV420()
{
    GLuint textureId[3];
}
@property(nonatomic,assign) GLuint positionId;
@property(nonatomic,assign) GLuint inputTextureCoordinateId;
@property(nonatomic,assign) GLuint colorConversionMatrixId;
@end

@implementation FFGLProgramYUV420

+ (instancetype)program
{
	return [[self alloc]initWithVertexShader:kFFPassthroughVertexShaderString
							  fragmentShader:kFFYUV420FragmentShaderString];
}

- (instancetype)initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader
{
	self = [super initWithVertexShader:vertexShader fragmentShader:fragmentShader];

	if(self)
	{
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			glGenTextures(3, gl_texture_ids);
		});

		[self initParams];
	}

	return self;
}

- (void)initParams
{
	self.positionId = [self bindAttribute:@"position"];
	self.inputTextureCoordinateId = [self bindAttribute:@"inputTextureCoordinate"];
	self.colorConversionMatrixId = [self bindUniform:@"colorConversionMatrix"];

	textureId[0] = [self bindUniform:@"texture_y"];
	textureId[1] = [self bindUniform:@"texture_u"];
	textureId[2] = [self bindUniform:@"texture_v"];

	glEnableVertexAttribArray(self.inputTextureCoordinateId);
	glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, opengl_rotate_matrix(FFRotationMode_R0));

	glEnableVertexAttribArray(self.positionId);
	glVertexAttribPointer(self.positionId, 2, GL_FLOAT, GL_FALSE, 0, gl_vertex_matrix());
	
	glUniformMatrix3fv(self.colorConversionMatrixId, 1, GL_FALSE, kFFColorConversion709);
}

- (void)render:(FFVideoFrame*)frame
{
	runAsync(^{
		if(!frame) return;
		if(frame.type != FFFrameTypeVideoYUV420) return;

		//need to update every times
		glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, opengl_rotate_matrix(frame.rotateMode));
		glVertexAttribPointer(self.positionId, 2, GL_FLOAT, GL_FALSE, 0, gl_vertex_matrix());

		glUniformMatrix3fv(self.colorConversionMatrixId, 1, GL_FALSE, kFFColorConversion709);

		const int frameWidth  = frame.width;
		const int frameHeight = frame.height;

		glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

		const int widths[3]  = {
			frameWidth,
			frameWidth / 2,
			frameWidth / 2
		};
		const int heights[3] = {
			frameHeight,
			frameHeight / 2,
			frameHeight / 2
		};

		const UInt8 *pixels[3] = {
			frame.luma.bytes,
			frame.chromaB.bytes,
			frame.chromaR.bytes };

		for (int channel=0; channel<3; channel++)
		{
			glActiveTexture(GL_TEXTURE0 + channel);
			glBindTexture(GL_TEXTURE_2D, gl_texture_ids[channel]);
			glTexImage2D(GL_TEXTURE_2D,
						 0,
						 GL_LUMINANCE,
						 widths[channel],
						 heights[channel],
						 0,
						 GL_LUMINANCE,
						 GL_UNSIGNED_BYTE,
						 pixels[channel]);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		}

		for(int i=0;i<3;i++)
		{
			glActiveTexture(GL_TEXTURE0 + i);
			glBindTexture(GL_TEXTURE_2D, gl_texture_ids[i]);
			glUniform1i(self->textureId[i], i);
		}
	});
}

@end
