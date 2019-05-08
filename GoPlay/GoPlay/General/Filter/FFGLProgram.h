//
//  FFGLProgram.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "FFHeader.h"
@class FFFramebuffer;
@class FFVideoFrame;

@interface FFGLProgram : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithVertexShader:(NSString *)vertexShader
						 fragmentShader:(NSString *)fragmentShader;

- (instancetype)initWithFragmentShader:(NSString *)fragmentShader;

@property (nonatomic, assign) GLint programId;

- (void)use;
- (void)render:(FFVideoFrame*)frame;

- (GLuint)bindAttribute:(NSString *)attributeName;
- (GLuint)bindUniform:(NSString *)uniformName;

@end
