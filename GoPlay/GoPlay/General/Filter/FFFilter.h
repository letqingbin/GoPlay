//
//  FFFilter.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "FFOutput.h"
@class FFFramebuffer;
@class FFGLProgram;

@interface FFFilter : FFOutput<FFInputProtocol>

@property(nonatomic,strong) FFFramebuffer* inputFramebuffer;
@property(nonatomic,assign) CGSize framebufferSize;
@property(nonatomic,assign) FFRotationMode rotationMode;

//overload
- (void)didUpdateProgram;
- (void)didBindProgram;
- (void)didUpdateParameter;
- (void)didUpdateFilter;
- (void)didDrawCall;
- (void)didEndUpdateFilter;

- (void)render;
- (void)infromTargetsAboutNewFrameAtTime:(NSTimeInterval)time;

//program
@property(nonatomic,strong) FFGLProgram* program;
@property(nonatomic,assign) GLuint positionId;
@property(nonatomic,assign) GLuint inputTextureCoordinateId;
@property(nonatomic,assign) GLuint inputImageTextureId;

@end
