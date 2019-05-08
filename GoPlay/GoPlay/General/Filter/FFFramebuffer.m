//
//  FFFramebuffer.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFFramebuffer.h"
#import "ReactiveCocoa.h"
#import "FFGLContext.h"

static const void* const kFFFramebufferQueueSpecificKey = &kFFFramebufferQueueSpecificKey;

@interface FFFramebuffer()
@property(nonatomic,assign) GLuint framebufferId;
@property(nonatomic,assign) GLuint textureId;
@property(nonatomic,weak) EAGLContext* context;

@property(nonatomic,strong) dispatch_queue_t queue;
@property(nonatomic,strong) NSRecursiveLock *mutex;
@end

@implementation FFFramebuffer

- (instancetype)initWithSize:(CGSize)size
{
	EAGLContext* context = [[FFGLContext shareInstance] context];
	return [self initWithSize:size ctx:context options:[FFFramebuffer defaultTextureOptions]];
}

- (instancetype)initWithSize:(CGSize)size
						 ctx:(EAGLContext*)context
					 options:(FFGPUTextureOptions)options
{
	self = [super init];

	if(self)
	{
		self.size = size;
		self.context = context;
		self.options = options;

		self.queue = dispatch_queue_create( "com.framebuffer.queue", DISPATCH_QUEUE_SERIAL);
		dispatch_queue_set_specific(self.queue, kFFFramebufferQueueSpecificKey, (__bridge void *)self, NULL);

		self.enableReferenceCount = NO;
		self.referenceCount = 0;
		self.mutex = [[NSRecursiveLock alloc]init];
		
		[self generateFramebuffer];
	}

	return self;
}

+ (FFGPUTextureOptions)defaultTextureOptions
{
	FFGPUTextureOptions options;
	options.minFilter = GL_LINEAR;
	options.magFilter = GL_LINEAR;
	options.wrapS = GL_CLAMP_TO_EDGE;
	options.wrapT = GL_CLAMP_TO_EDGE;
	options.internalFormat = GL_RGBA;
	options.format = GL_BGRA;
	options.type = GL_UNSIGNED_BYTE;

	return options;
}

- (void)generateFramebuffer
{
	[[FFGLContext shareInstance] useCurrentContext];

	glGenFramebuffers(1, &_framebufferId);
	glBindFramebuffer(GL_FRAMEBUFFER, self.framebufferId);

	[self generateTexture];

	glBindTexture(GL_TEXTURE_2D, self.textureId);
	glTexImage2D(GL_TEXTURE_2D,
				 0,
				 self.options.internalFormat,
				 self.size.width,
				 self.size.height,
				 0,
				 self.options.format,
				 self.options.type,
				 NULL);

	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, self.textureId, 0);
	
#ifndef NS_BLOCK_ASSERTIONS
	GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	NSAssert(status == GL_FRAMEBUFFER_COMPLETE, @"Incomplete filter FBO: %d", status);
#endif

	glBindTexture(GL_TEXTURE_2D, 0);
}

- (void)generateTexture
{
	glActiveTexture(GL_TEXTURE1);
	glGenTextures(1, &_textureId);
	glBindTexture(GL_TEXTURE_2D, _textureId);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, self.options.minFilter);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, self.options.magFilter);
	// This is necessary for non-power-of-two textures
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, self.options.wrapS);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, self.options.wrapT);
}

- (CGImageRef)newCGImageFromFramebufferContents
{
	NSAssert(self.options.internalFormat == GL_RGBA, @"For conversion to a CGImage the output texture format for this filter must be GL_RGBA.");
	NSAssert(self.options.type == GL_UNSIGNED_BYTE, @"For conversion to a CGImage the type of the output texture of this filter must be GL_UNSIGNED_BYTE.");

	[self lock];
	[[FFGLContext shareInstance] useCurrentContext];

	__block CGImageRef cgImageFromBytes = nil;
	NSUInteger totalBytesForImage = (int)_size.width * (int)_size.height * 4;
	// It appears that the width of a texture must be padded out to be a multiple of 8 (32 bytes) if reading from it using a texture cache
	GLubyte *rawImagePixels;
	CGDataProviderRef dataProvider = NULL;

	[self activateFramebuffer];
	rawImagePixels = (GLubyte *)malloc(totalBytesForImage);
	glReadPixels(0,
				 0,
				 (int)_size.width,
				 (int)_size.height,
				 GL_RGBA,
				 GL_UNSIGNED_BYTE,
				 rawImagePixels);

	dataProvider = CGDataProviderCreateWithData(NULL,
												rawImagePixels,
												totalBytesForImage,
												dataProviderReleaseCallback);
	
	CGColorSpaceRef defaultRGBColorSpace = CGColorSpaceCreateDeviceRGB();
	 cgImageFromBytes = CGImageCreate((int)_size.width,
									  (int)_size.height,
									  8,
									  32,
									  4 * (int)_size.width,
									  defaultRGBColorSpace,
									  kCGBitmapByteOrderDefault | kCGImageAlphaLast,
									  dataProvider,
									  NULL,
									  NO,
									  kCGRenderingIntentDefault);
	CGDataProviderRelease(dataProvider);
	CGColorSpaceRelease(defaultRGBColorSpace);

	[self unlock];
	return cgImageFromBytes;
}

static void dataProviderReleaseCallback (void *info, const void *data, size_t size)
{
	free((void *)data);
}

- (void)destroyFramebuffer
{
	[[FFGLContext shareInstance] useCurrentContext];

	if(self.framebufferId)
	{
		glDeleteFramebuffers(1, &_framebufferId);
		self.framebufferId = 0;
	}

	if(self.textureId)
	{
		glDeleteTextures(1, &_textureId);
		self.textureId = 0;
	}
}

- (void)activateFramebuffer
{
	glBindFramebuffer(GL_FRAMEBUFFER, self.framebufferId);
	glViewport(0, 0, (int)self.size.width, (int)self.size.height);
}

- (void)lock
{
	if(!self.enableReferenceCount) return;
	self.referenceCount++;

	if(self.delegate && [self.delegate respondsToSelector:@selector(framebufferDidLock:)])
	{
		[self.delegate framebufferDidLock:self];
	}
}

- (void)unlock
{
	[self.mutex lock];

    if(!self.enableReferenceCount || self.referenceCount <= 0)
    {
        [self.mutex unlock];
        return;
    }
	self.referenceCount--;

	if(self.delegate && [self.delegate respondsToSelector:@selector(framebufferDidUnlock:)])
	{
		[self.delegate framebufferDidUnlock:self];
	}

	[self.mutex unlock];
}

- (void) clearAllLock
{
	[self.mutex lock];
    
    if(!self.enableReferenceCount || self.referenceCount <= 0)
    {
        [self.mutex unlock];
        return;
    }
	self.referenceCount = 0;

	if(self.delegate && [self.delegate respondsToSelector:@selector(framebufferDidUnlock:)])
	{
		[self.delegate framebufferDidUnlock:self];
	}

	[self.mutex unlock];
}

- (void) asyncOnQueue:(void (^)(void)) block
{
	if(dispatch_get_specific(kFFFramebufferQueueSpecificKey))
	{
		if(block)
		{
			block();
		}
	}
	else
	{
		dispatch_async(self.queue, block);
	}
}

- (GLuint)texture
{
	return self.textureId;
}

- (void)dealloc
{
	[self destroyFramebuffer];
	LOG_INFO(@"%@ release", self.class);
}

@end
