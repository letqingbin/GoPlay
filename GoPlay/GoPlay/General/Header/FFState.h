//
//  FFState.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/27.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFState : NSObject
@property(nonatomic,assign) int playing;
@property(nonatomic,assign) int paused;
@property(nonatomic,assign) int seeking;
@property(nonatomic,assign) int error;
@property(nonatomic,assign) int endOfFile;

@property(nonatomic,assign) int flushed;

//after seeking and paused, show one frame;
@property(nonatomic,assign) int snapshot;
@property(nonatomic,assign) int readyToDecode;
@property(nonatomic,assign) int destroyed;
@property(nonatomic,assign) int autoPlay;

- (void)clearAllSates;
@end
