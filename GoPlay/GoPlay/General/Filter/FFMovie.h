//
//  FFMovie.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFOutput.h"
#import "FFFrame.h"

@interface FFMovie : FFOutput
@property(nonatomic,assign) FFRotationMode mode;
- (void)render:(FFVideoFrame*)frame;
@end
