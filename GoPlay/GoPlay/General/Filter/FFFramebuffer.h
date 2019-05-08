//
//  FFFramebuffer.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFHeader.h"
@class FFFramebuffer;

@protocol FFFramebufferDelegate<NSObject>
@optional
- (void) framebufferDidLock:(FFFramebuffer*)framebuffer;
- (void) framebufferDidUnlock:(FFFramebuffer*)framebuffer;
@end

@interface FFFramebuffer : NSObject

- (instancetype)initWithSize:(CGSize)size;

- (instancetype)initWithSize:(CGSize)size
						 ctx:(EAGLContext*)context
					 options:(FFGPUTextureOptions)options;

- (void)activateFramebuffer;
- (GLuint)texture;
- (CGImageRef)newCGImageFromFramebufferContents;
+ (FFGPUTextureOptions)defaultTextureOptions;

@property(nonatomic,weak) id<FFFramebufferDelegate> delegate;
@property(nonatomic,assign) BOOL enableReferenceCount;
@property(nonatomic,assign) NSInteger referenceCount;

- (void) lock;
- (void) unlock;
- (void) clearAllLock;

@property(nonatomic,assign) CGSize size;
@property(nonatomic,assign) FFGPUTextureOptions options;

@end
