//
//  FFGLContext.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface FFGLContext : NSObject
+ (instancetype)shareInstance;
- (EAGLContext*)context;
- (CVOpenGLESTextureCacheRef)videoTextureCache;
- (void)useCurrentContext;
@end
