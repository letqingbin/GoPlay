//
//  FFGLProgram.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFGLProgram.h"
#import "FFFramebuffer.h"

#import "FFVertexMatrix.h"
#import "GLSL.h"

@interface FFGLProgram ()

@property(nonatomic,copy) NSString* vertexShaderString;
@property(nonatomic,copy) NSString* fragmentShaderString;
@property(nonatomic,assign) GLuint vertexShaderId;
@property(nonatomic,assign) GLuint fragmentShaderId;
@end

@implementation FFGLProgram

- (instancetype)initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader
{
	if (self = [super init])
	{
		self.vertexShaderString = vertexShader;
		self.fragmentShaderString = fragmentShader;

		[self initProgram];
		[self use];
	}
	return self;
}

- (instancetype)initWithFragmentShader:(NSString *)fragmentShader
{
	self = [super init];

	if(self)
	{
		self.vertexShaderString = kFFPassthroughVertexShaderString;
		self.fragmentShaderString = fragmentShader;

		[self initProgram];
		[self use];
	}

	return self;
}

- (void)use
{
	glUseProgram(_programId);
}

- (void)render:(FFVideoFrame*)frame
{}

- (void)initProgram
{
	_programId = glCreateProgram();

	// setup shader
	if (![self compileShader:&_vertexShaderId type:GL_VERTEX_SHADER string:self.vertexShaderString.UTF8String])
	{
		LOG_ERROR(@"load vertex shader failure");
	}
	if (![self compileShader:&_fragmentShaderId type:GL_FRAGMENT_SHADER string:self.fragmentShaderString.UTF8String])
	{
		LOG_ERROR(@"load fragment shader failure");
	}

	glAttachShader(_programId, _vertexShaderId);
	glAttachShader(_programId, _fragmentShaderId);

	GLint logLength, status;
	glLinkProgram(_programId);

	glGetProgramiv(_programId, GL_INFO_LOG_LENGTH, &logLength);
	if (logLength > 0)
	{
		GLchar *log = (GLchar *)malloc(logLength);
		glGetProgramInfoLog(_programId, logLength, &logLength, log);
		LOG_INFO(@"Program link log:\n%s", log);
		free(log);
	}

	glGetProgramiv(_programId, GL_LINK_STATUS, &status);
	if (status == GL_FALSE)
	{
		LOG_ERROR(@"Failed to link program %d", _programId);
	}
	glError();

	[self clearShader];
}

- (BOOL)compileShader:(GLuint *)shader
				 type:(GLenum)type
			   string:(const char *)shaderString
{
	if (!shaderString)
	{
		LOG_ERROR(@"Failed to load shader");
		return NO;
	}

	GLint status;

	*shader = glCreateShader(type);
	glShaderSource(* shader, 1, &shaderString, NULL);
	glCompileShader(* shader);
	glGetShaderiv(* shader, GL_COMPILE_STATUS, &status);

	if (status != GL_TRUE)
	{
		GLint logLength;
		glGetShaderiv(* shader, GL_INFO_LOG_LENGTH, &logLength);
		if (logLength > 0)
		{
			GLchar * log = (GLchar *)malloc(logLength);
			glGetShaderInfoLog(* shader, logLength, &logLength, log);
			LOG_INFO(@"Shader compile log:\n%s", log);
			free(log);
		}
	}

	return status == GL_TRUE;
}

- (void)clearShader
{
	if (_vertexShaderId)
	{
		glDeleteShader(_vertexShaderId);
	}

	if (_fragmentShaderId)
	{
		glDeleteShader(_fragmentShaderId);
	}

	glError();
}

- (void)clearProgram
{
	if (_programId)
	{
		glDeleteProgram(_programId);
		_programId = 0;
	}
}

- (GLuint)bindAttribute:(NSString *)attributeName
{
	return (GLuint)glGetAttribLocation(self.programId, [attributeName UTF8String]);
}

- (GLuint)bindUniform:(NSString *)uniformName
{
	return glGetUniformLocation(self.programId, [uniformName UTF8String]);
}

- (void)dealloc
{
	[self clearProgram];
	LOG_INFO(@"%@ release", self.class);
}


@end
