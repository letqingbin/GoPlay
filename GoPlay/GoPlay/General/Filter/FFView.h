//
//  FFView.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FFHeader.h"
#import "FFOutput.h"
#import "FFGLProgram.h"

@interface FFView : UIView<FFInputProtocol>

@property(nonatomic,assign) FFFillMode fillMode;
@property(nonatomic,strong) FFGLProgram* program;

@property(nonatomic,assign) CGSize framebufferSize;
@property(nonatomic,assign) GLuint framebufferId;
@property(nonatomic,assign) GLuint renderbufferId;

@property(nonatomic,assign) FFRotationMode rotationMode;
@property(nonatomic,strong) FFFramebuffer* inputFramebuffer;

@property(nonatomic,assign) CGSize viewportSize;

- (void)reset;
- (void)updateFillMode;
@end
