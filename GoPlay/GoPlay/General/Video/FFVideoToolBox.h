//
//  FFVideoToolBox.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/11.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "avformat.h"
@class FFVideoDecoderModel;

@interface FFVideoToolBox : NSObject

+ (instancetype)decoderWithModel:(FFVideoDecoderModel*)model;

- (void)flushPacket:(AVPacket)packet;
- (BOOL)sendPacket:(AVPacket)packet needFlush:(BOOL *)needFlush;
- (CVImageBufferRef)imageBuffer;

- (BOOL)trySetupVTSession;
- (void)flush;

@end
