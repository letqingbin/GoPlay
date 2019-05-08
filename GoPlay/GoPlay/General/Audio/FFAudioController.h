//
//  FFAudioController.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/15.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
@class FFAudioController;

@protocol FFAudioControllerDelegate <NSObject>
@optional
- (void)audioController:(FFAudioController *)audioController
          outputData:(float *)outputData
      numberOfFrames:(UInt32)numberOfFrames
    numberOfChannels:(UInt32)numberOfChannels;
@end

@interface FFAudioController : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)controller;
- (void)play;
- (void)pause;

- (BOOL)registerAudioSession;
- (void)unregisterAudioSession;

@property(nonatomic,assign) BOOL playing;
@property(nonatomic,assign) float volume;
@property(nonatomic,assign) UInt32  numOutputChannels;
@property(nonatomic,assign) Float64 sampleRate;
@property(nonatomic,weak) id<FFAudioControllerDelegate> delegate;
@end
