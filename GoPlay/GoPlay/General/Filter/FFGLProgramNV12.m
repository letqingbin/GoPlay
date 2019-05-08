//
//  FFGLProgramNV12.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/11.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFGLProgramNV12.h"
#import "FFHeader.h"
#import "FFGLContext.h"
#import "FFVertexMatrix.h"
#import "FFColorConversionHeader.h"

#import "avformat.h"
#import "GLSL.h"

@interface FFGLProgramNV12()
@property(nonatomic,assign) GLuint positionId;
@property(nonatomic,assign) GLuint inputTextureCoordinateId;
@property(nonatomic,assign) GLuint colorConversionMatrixId;
@property(nonatomic,assign) GLuint luminanceTextureId;
@property(nonatomic,assign) GLuint chrominanceTextureId;

@property(nonatomic,assign) CVOpenGLESTextureRef lumaTextureRef;
@property(nonatomic,assign) CVOpenGLESTextureRef chromaTextureRef;
@property(nonatomic,assign) CVOpenGLESTextureCacheRef videoTextureCache;

@property(nonatomic,assign) CFTypeRef color_attachments;
@end

@implementation FFGLProgramNV12

+ (instancetype)program
{
    return [[self alloc]initWithVertexShader:kFFPassthroughVertexShaderString
                              fragmentShader:kFFNV12VideoRangeFragmentShaderString];
}

- (instancetype)initWithVertexShader:(NSString *)vertexShader fragmentShader:(NSString *)fragmentShader
{
    self = [super initWithVertexShader:vertexShader fragmentShader:fragmentShader];
    
    if(self)
    {
		[self initParams];
    }
    
    return self;
}

- (void)initParams
{
    self.positionId = [self bindAttribute:@"position"];
    self.inputTextureCoordinateId = [self bindAttribute:@"inputTextureCoordinate"];
    
    self.luminanceTextureId   = [self bindUniform:@"luminanceTexture"];
    self.chrominanceTextureId = [self bindUniform:@"chrominanceTexture"];
    
    self.colorConversionMatrixId = [self bindUniform:@"colorConversionMatrix"];

    glEnableVertexAttribArray(self.inputTextureCoordinateId);
    glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, opengl_rotate_matrix(FFRotationMode_R0));

    glEnableVertexAttribArray(self.positionId);
    glVertexAttribPointer(self.positionId, 2, GL_FLOAT, GL_FALSE, 0, gl_vertex_matrix());

	self.color_attachments = kCVImageBufferYCbCrMatrix_ITU_R_709_2;
    glUniformMatrix3fv(self.colorConversionMatrixId, 1, GL_FALSE, kFFColorConversion709);

    if (!self.videoTextureCache)
    {
        CVReturn result = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault,
                                                       NULL,
                                                       [[FFGLContext shareInstance] context],
                                                       NULL,
                                                       &_videoTextureCache);
        if (result != noErr)
        {
            LOG_ERROR(@"create CVOpenGLESTextureCacheCreate failure %d", result);
            return;
        }
    }
}

- (void)render:(FFVideoFrame *)frame
{
	runAsync(^{
		if(!frame) return;
		if(frame.type != FFFrameTypeVideoNV12) return;

		FFVideoFrameNV12* nv12Frame = (FFVideoFrameNV12*)frame;

		//need to update every times
		glVertexAttribPointer(self.inputTextureCoordinateId, 2, GL_FLOAT, GL_FALSE, 0, opengl_rotate_matrix(frame.rotateMode));
		glVertexAttribPointer(self.positionId, 2, GL_FLOAT, GL_FALSE, 0, gl_vertex_matrix());

		CVPixelBufferRef pixelBuffer = nv12Frame.pixelBuffer;

		int frameHeight = (int) CVPixelBufferGetHeight(pixelBuffer);
		int frameWidth  = (int) CVPixelBufferGetWidth(pixelBuffer);

		[self cleanTextures];

		CFTypeRef color_attachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
		if (color_attachments != self.color_attachments)
		{
			if (color_attachments == nil)
			{
				//bt.709
				glUniformMatrix3fv(self.colorConversionMatrixId, 1, GL_FALSE, kFFColorConversion709);
			}
			else if (self.color_attachments != nil &&
					 CFStringCompare(color_attachments, self.color_attachments, 0) == kCFCompareEqualTo)
			{
				// remain prvious color attachment
			}
			else if (CFStringCompare(color_attachments, kCVImageBufferYCbCrMatrix_ITU_R_709_2, 0) == kCFCompareEqualTo)
			{
				//bt.709
				glUniformMatrix3fv(self.colorConversionMatrixId, 1, GL_FALSE, kFFColorConversion709);
			}
			else if (CFStringCompare(color_attachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo)
			{
				//bt.601
				glUniformMatrix3fv(self.colorConversionMatrixId, 1, GL_FALSE, kFFColorConversion601);
			}
			else
			{
				//bt.2020
				if(@available(iOS 9,*))
				{
					if(CFStringCompare(color_attachments, kCVImageBufferYCbCrMatrix_ITU_R_2020, 0) == kCFCompareEqualTo)
					{
						glUniformMatrix3fv(self.colorConversionMatrixId, 1, GL_FALSE, kFFColorConversion2020);
					}
					else
					{
						//bt.709
						glUniformMatrix3fv(self.colorConversionMatrixId, 1, GL_FALSE, kFFColorConversion709);
					}
				}
				else
				{
					//bt.709
					glUniformMatrix3fv(self.colorConversionMatrixId, 1, GL_FALSE, kFFColorConversion709);
				}
			}

			if (self.color_attachments != nil)
			{
				CFRelease(self.color_attachments);
				self.color_attachments = nil;
			}

			if (color_attachments != nil)
			{
				self.color_attachments = CFRetain(color_attachments);
			}
		}

		CVReturn result;
		// Y-plane
		glActiveTexture(GL_TEXTURE0);
		result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
															  self.videoTextureCache,
															  pixelBuffer,
															  NULL,
															  GL_TEXTURE_2D,
															  GL_LUMINANCE,
															  frameWidth,
															  frameHeight,
															  GL_LUMINANCE,
															  GL_UNSIGNED_BYTE,
															  0,
															  &self->_lumaTextureRef);

		if (result == kCVReturnSuccess)
		{
			glBindTexture(CVOpenGLESTextureGetTarget(self.lumaTextureRef), CVOpenGLESTextureGetName(self.lumaTextureRef));
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		}
		else
		{
			LOG_ERROR(@"create CVOpenGLESTextureCacheCreateTextureFromImage failure 1 %d", result);
		}

		// UV-plane.
		glActiveTexture(GL_TEXTURE1);
		result = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
															  self.videoTextureCache,
															  pixelBuffer,
															  NULL,
															  GL_TEXTURE_2D,
															  GL_LUMINANCE_ALPHA,
															  frameWidth/2,
															  frameHeight/2,
															  GL_LUMINANCE_ALPHA,
															  GL_UNSIGNED_BYTE,
															  1,
															  &self->_chromaTextureRef);

		if (result == kCVReturnSuccess)
		{
			glBindTexture(CVOpenGLESTextureGetTarget(self.chromaTextureRef), CVOpenGLESTextureGetName(self.chromaTextureRef));
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		}
		else
		{
			LOG_ERROR(@"create CVOpenGLESTextureCacheCreateTextureFromImage failure 2 %d", result);
		}

		glActiveTexture(GL_TEXTURE2);
		glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(self.lumaTextureRef));
		glUniform1i(self.luminanceTextureId, 2);

		glActiveTexture(GL_TEXTURE3);
		glBindTexture(GL_TEXTURE_2D, CVOpenGLESTextureGetName(self.chromaTextureRef));
		glUniform1i(self.chrominanceTextureId, 3);
	});
}

- (void)cleanTextures
{
    if (self.lumaTextureRef)
    {
        CFRelease(_lumaTextureRef);
        self.lumaTextureRef = NULL;
    }
    
    if (self.chromaTextureRef)
    {
        CFRelease(_chromaTextureRef);
        self.chromaTextureRef = NULL;
    }
    
    CVOpenGLESTextureCacheFlush(self.videoTextureCache, 0);
}

- (void)clearVideoCache
{
    if (self.videoTextureCache)
    {
        CFRelease(_videoTextureCache);
        self.videoTextureCache = nil;
    }
}

- (void)dealloc
{
    [self clearVideoCache];
    [self cleanTextures];
}

@end
