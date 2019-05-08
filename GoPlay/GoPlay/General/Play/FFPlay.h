//
//  FFPlay.h
//  GoPlay
//
//  Created by dKingbin on 2018/9/1.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFDecoder.h"
#import "FFAudioController.h"

@class FFMovie;
@class FFState;
@class FFMediaInfoModel;

@interface FFPlay : NSObject
@property(nonatomic,copy)   NSString* url;
@property(nonatomic,strong) FFMovie* ffMovie;
@property(nonatomic,strong) FFState* state;

- (void)play;
- (void)pause;
- (void)destroy;
- (void)seekToTimeByValue:(NSTimeInterval)time;
- (void)seekToTimeByRatio:(float)ratio;

@property(nonatomic,strong) FFDecoder* decoder;
@property(nonatomic,strong) FFAudioController* audioController;
@property(nonatomic,assign) double position;

@property(nonatomic,copy) void(^didUpdateStreamsInfoBlock)(FFMediaInfoModel*);
@end


