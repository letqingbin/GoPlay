//
//  FFState.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/27.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFState.h"

@implementation FFState

- (instancetype)init
{
	self = [super init];
	if(self)
	{
		self.paused = 1;
	}

	return self;
}

- (void)clearAllSates
{
	self.playing = 0;
	self.paused  = 0;
	self.seeking = 0;
	self.error   = 0;
	self.endOfFile = 0;
    self.flushed   = 0;
    self.snapshot  = 0;
	self.autoPlay  = 0;

	//readyToDecode shouldn't reset
}

- (void)setPlaying:(int)playing
{
	if(_playing == playing) return;
	_playing = playing;
	_paused  = !playing;
}

- (void)setPaused:(int)paused
{
	if(_paused == paused) return;
	_paused  = paused;
	_playing = !paused;
}

@end
