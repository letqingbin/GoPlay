//
//  FFView.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFView.h"

#import "FFHeader.h"
#import "FFFramebuffer.h"
#import "FFFramebufferPool.h"
#import "FFGLContext.h"
#import "FFVertexMatrix.h"
#import "GLSL.h"

#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>

@interface FFView()
{
	float vertices[8];
}

@property(nonatomic,assign) GLuint positionId;
@property(nonatomic,assign) GLuint inputTextureCoordinateId;
@property(nonatomic,assign) GLuint inputImageTextureId;

@property(nonatomic,assign) CGSize boundsSizeAtFrameBufferEpoch;
@end

@implementation FFView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];

	if(self)
	{
		static float m_vertex[] = {
			-1.0, -1.0f,
			1.0f, -1.0f,
			-1.0f, 1.0f,
			 1.0f, 1.0f,
		};
		/*
		 3     4
		 1     2
		 */

		memcpy(vertices, m_vertex, sizeof(float)*8);

		CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
		eaglLayer.opaque = YES;
		eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
										[NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
										kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
										nil];

		self.contentScaleFactor = [UIScreen mainScreen].scale;
        self.boundsSizeAtFrameBufferEpoch = self.bounds.size;
        
		[self initProgram];
		[self setupRenderBuffers];
	}

	return self;
}

- (void)reset
{
	runAsync(^{
		self.rotationMode = FFRotationMode_R0;
	});
}

- (void)initProgram
{
	[[FFGLContext shareInstance] useCurrentContext];
	self.program = [[FFGLProgram alloc]initWithVertexShader:kFFPassthroughVertexShaderString
											 fragmentShader:kFFPassthroughFragmentShaderString];

	self.positionId = [self.program bindAttribute:@"position"];
	self.inputTextureCoordinateId = [self.program bindAttribute:@"inputTextureCoordinate"];
	self.inputImageTextureId = [self.program bindUniform:@"inputImageTexture"];

	glEnableVertexAttribArray(self.inputTextureCoordinateId);
	glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, glkit_rotate_matrix(self.rotationMode));

	glEnableVertexAttribArray(self.positionId);
	glVertexAttribPointer(self.positionId, 2, GL_FLOAT, GL_FALSE, 0, vertices);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    if(!CGSizeEqualToSize(self.bounds.size, self.boundsSizeAtFrameBufferEpoch)
       && !CGSizeEqualToSize(self.bounds.size, CGSizeZero))
    {
        runAsync(^{
            [self clearRenderBuffers];
            [self setupRenderBuffers];
        });
    }
}

- (void)setupRenderBuffers
{
	[[FFGLContext shareInstance] useCurrentContext];

	glGenFramebuffers(1, &_framebufferId);
	glBindFramebuffer(GL_FRAMEBUFFER, _framebufferId);

	glGenRenderbuffers(1, &_renderbufferId);
	glBindRenderbuffer(GL_RENDERBUFFER, _renderbufferId);

	runSyncOnMainQueue(^{
		[[[FFGLContext shareInstance] context] renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
	});

	GLint renderWidth;
	GLint renderHeight;
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &renderWidth);
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &renderHeight);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbufferId);

	self.viewportSize = CGSizeMake(renderWidth, renderHeight);
    
	//check success
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
	{
		LOG_ERROR(@"failed to make complete framebuffer object: %i", glCheckFramebufferStatus(GL_FRAMEBUFFER));
	}

	//unbind
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	
    __block CGSize bounds;
    runSyncOnMainQueue(^{
        bounds = self.bounds.size;
    });
    self.boundsSizeAtFrameBufferEpoch = bounds;
    
	glError();
}

- (void)updateFillMode
{
    __block CGRect bounds;
    __block CGSize bound_size;
    __block int bound_size_height;
    __block int bound_size_width;
    
	runSyncOnMainQueue(^{
        bounds = self.bounds;
        bound_size = self.bounds.size;
        bound_size_height = self.bounds.size.height;
        bound_size_width  = self.bounds.size.width;
	});

    int screenWidth  = bound_size_width;
    int screenHeight = bound_size_height;
    
	float ratio = 0.0;
	if(self.fillMode == FillModeLandscape16_9)
	{
		ratio = 16.0/9;
	}
	else if(self.fillMode == FillModeLandscape4_3)
	{
		ratio = 4.0/3;
	}
	else if(self.fillMode == FillModePortrait9_16)
	{
		ratio = 9.0/16;
	}
	else if(self.fillMode == FillModePortrait3_4)
	{
		ratio = 3.0/4;
	}

    CGRect frame = bounds;

	if(ratio != 0.0)
	{
		float screenRatio = (float)screenWidth / screenHeight;
		if(ff_swap_wh(self.rotationMode))
		{
			screenWidth  = bound_size_height;
			screenHeight = bound_size_width;
			screenRatio = (float)screenWidth / screenHeight;
		}

		if(screenRatio < ratio)
		{
            float height = screenWidth / ratio;
            frame = CGRectMake(0, (screenHeight - height)/2, screenWidth, height);
		}
		else if(screenRatio > ratio)
		{
            float width = screenHeight * ratio;
            frame = CGRectMake((screenWidth - width)/2, 0, width, screenHeight);
		}
	}
    
    CGRect insetRect;
    if(self.fillMode == FillModePreserveAspectRatioAndFill
       || self.fillMode == FillModeStretch
       || self.fillMode == FillModePreserveAspectRatio)
    {
        insetRect = AVMakeRectWithAspectRatioInsideRect(self.framebufferSize, frame);
    }
    else
    {
        insetRect = AVMakeRectWithAspectRatioInsideRect(frame.size, bounds);
    }
    
    CGFloat heightScaling, widthScaling;

    switch (self.fillMode) {
        case FillModePreserveAspectRatioAndFill:
            widthScaling  = screenHeight / insetRect.size.height;
            heightScaling = screenWidth / insetRect.size.width;
            break;
        case FillModeStretch:
            widthScaling  = 1.0;
            heightScaling = 1.0;
            break;
        case FillModePreserveAspectRatio:
            widthScaling  = insetRect.size.width / screenWidth;
            heightScaling = insetRect.size.height / screenHeight;
            break;
        default:
			widthScaling  = insetRect.size.width / screenWidth;
			heightScaling = insetRect.size.height / screenHeight;
            break;
    }
    
    vertices[0] = -widthScaling;
    vertices[1] = -heightScaling;
    vertices[2] = widthScaling;
    vertices[3] = -heightScaling;
    vertices[4] = -widthScaling;
    vertices[5] = heightScaling;
    vertices[6] = widthScaling;
    vertices[7] = heightScaling;
}

- (void)render
{
	runAsync(^{
		[[FFGLContext shareInstance] useCurrentContext];
		[self.program use];

		glBindFramebuffer(GL_FRAMEBUFFER, self.framebufferId);
		glViewport(0, 0, self.viewportSize.width, self.viewportSize.height);

		glClearColor(0.0, 0.0, 0.0, 1.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		glActiveTexture(GL_TEXTURE5);
		glBindTexture(GL_TEXTURE_2D, [self.inputFramebuffer texture]);
		glUniform1i(self.inputImageTextureId, 5);

		//need to update every times
		glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, glkit_rotate_matrix(self.rotationMode));

		[self updateFillMode];
		glVertexAttribPointer(self.positionId, 2, GL_FLOAT, GL_FALSE, 0, self->vertices);

		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

		glBindRenderbuffer(GL_RENDERBUFFER, self.renderbufferId);
		[[[FFGLContext shareInstance] context] presentRenderbuffer:GL_RENDERBUFFER];
	});
}

+ (Class)layerClass
{
	return [CAEAGLLayer class];
}

- (CGSize)viewportSize
{
    if(CGSizeEqualToSize(CGSizeZero, _viewportSize))
    {
        if([self respondsToSelector:@selector(setContentScaleFactor:)])
        {
            __block CGSize pointSize;
            __block float scale;
            runSyncOnMainQueue(^{
                pointSize = self.bounds.size;
                scale = self.contentScaleFactor;
            });
            
            return CGSizeMake(scale*pointSize.width, scale*pointSize.height);
        }
        else
        {
            return self.bounds.size;
        }
    }
    
    return _viewportSize;
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

#pragma mark -- FFInputProtocol
- (void)setInputFramebuffer:(FFFramebuffer*)framebuffer atIndex:(NSInteger)index
{
	self.inputFramebuffer = framebuffer;
}

- (void) setInputRotate:(FFRotationMode)mode atIndex:(NSInteger)index
{
	self.rotationMode = mode;
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

- (void)newFrameReadyAtTime:(NSTimeInterval)time atIndex:(NSInteger)index
{
	[self render];
	[self.inputFramebuffer unlock];
	self.inputFramebuffer = nil;
}

- (NSInteger)nextAvailableTextureIndex
{
	return 0;
}

- (void)endProcess
{}

@end
