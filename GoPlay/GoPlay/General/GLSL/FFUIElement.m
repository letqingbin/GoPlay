//
//  FFUIElement.m
//  GoPlay
//
//  Created by dKingbin on 2019/5/8.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import "FFUIElement.h"

#import "FFGLContext.h"
#import "FFFramebuffer.h"
#import "FFFramebufferPool.h"

#import "FFHeader.h"
#import "FFVertexMatrix.h"

@interface FFUIElement()
{
	UIView *view;
	CALayer *layer;

	CGSize previousLayerSizeInPixels;
	CMTime time;
	NSTimeInterval actualTimeOfLastUpdate;
}

@end

@implementation FFUIElement

- (instancetype)initWithView:(UIView *)inputView;
{
	self = [super init];
	if(self)
	{
		view = inputView;
		layer = inputView.layer;

		previousLayerSizeInPixels = CGSizeZero;
		[self update];
	}

	return self;
}

- (instancetype)initWithLayer:(CALayer *)inputLayer;
{
	self = [super init];
	if(self)
	{
		view = nil;
		layer = inputLayer;

		previousLayerSizeInPixels = CGSizeZero;
		[self update];
	}

	return self;
}

- (CGSize)layerSizeInPixels;
{
	CGSize pointSize = layer.bounds.size;
	return CGSizeMake(layer.contentsScale * pointSize.width, layer.contentsScale * pointSize.height);
}

- (void)update;
{
	runAsync(^{
		[self updateWithTimestamp:-1];
	});
}

- (void)updateUsingCurrentTime;
{
	runAsync(^{
		if(CMTIME_IS_INVALID(self->time))
		{
			self->time = CMTimeMakeWithSeconds(0, 600);
			self->actualTimeOfLastUpdate = [NSDate timeIntervalSinceReferenceDate];
		}
		else
		{
			NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
			NSTimeInterval diff = now - self->actualTimeOfLastUpdate;
			self->time = CMTimeAdd(self->time, CMTimeMakeWithSeconds(diff, 600));
			self->actualTimeOfLastUpdate = now;
		}

		[self updateWithTimestamp:CMTimeGetSeconds(self->time)];
	});
}

- (void)updateWithTimestamp:(NSTimeInterval)frameTime;
{
	runAsync(^{
		[[FFGLContext shareInstance] useCurrentContext];

		CGSize layerPixelSize = [self layerSizeInPixels];

		GLubyte *imageData = (GLubyte *) calloc(1, (int)layerPixelSize.width * (int)layerPixelSize.height * 4);

		CGColorSpaceRef genericRGBColorspace = CGColorSpaceCreateDeviceRGB();
		CGContextRef imageContext = CGBitmapContextCreate(imageData,
														  (int)layerPixelSize.width,
														  (int)layerPixelSize.height,
														  8,
														  (int)layerPixelSize.width * 4,
														  genericRGBColorspace,
														  kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
		CGContextTranslateCTM(imageContext, 0.0f, layerPixelSize.height);
		CGContextScaleCTM(imageContext, self->layer.contentsScale, -self->layer.contentsScale);

		[self->layer renderInContext:imageContext];

		CGContextRelease(imageContext);
		CGColorSpaceRelease(genericRGBColorspace);

		self.outputFramebuffer = [[FFFramebufferPool shareInstance] getUnuseFramebufferBySize:layerPixelSize];
		[self.outputFramebuffer activateFramebuffer];

		glClearColor(0.0, 0.0, 0.0, 1.0);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		glBindTexture(GL_TEXTURE_2D, [self.outputFramebuffer texture]);
		glTexImage2D(GL_TEXTURE_2D,
					 0,
					 GL_RGBA,
					 (int)layerPixelSize.width,
					 (int)layerPixelSize.height,
					 0, GL_BGRA, GL_UNSIGNED_BYTE,
					 imageData);
		[self infromTargetsAboutNewFrameAtTime:frameTime];

		free(imageData);
	});
}

- (void)infromTargetsAboutNewFrameAtTime:(NSTimeInterval)time
{
	CGSize layerPixelSize = [self layerSizeInPixels];

	for(id<FFInputProtocol> target in self.targets)
	{
		NSInteger indexOfObject = [self.targets indexOfObject:target];
		NSInteger index = [[self.targetIndices objectAtIndex:indexOfObject] integerValue];
		[target setInputSize:layerPixelSize atIndex:index];
		[target setInputFramebuffer:self.outputFramebuffer atIndex:index];
	}

	for(id<FFInputProtocol> target in self.targets)
	{
		NSInteger indexOfObject = [self.targets indexOfObject:target];
		NSInteger index = [[self.targetIndices objectAtIndex:indexOfObject] integerValue];
		[target newFrameReadyAtTime:time atIndex:index];
	}
}

@end
