//
//  FFGLProgramYUV420
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFGLProgram.h"
#import "FFFrame.h"

static GLuint gl_texture_ids[3];

@interface FFGLProgramYUV420 : FFGLProgram
+ (instancetype)program;
@end
