//
//  FFPlay.m
//  GoPlay
//
//  Created by dKingbin on 2018/9/1.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFPlay.h"

#import "FFHeader.h"

#import "FFAudioDecoder.h"
#import "FFVideoDecoder.h"
#import "FFFrame.h"
#import "FFSeekContext.h"
#import "FFMovie.h"

#import <AVFoundation/AVFoundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "ReactiveCocoa.h"
#import "CommonUtil.h"
#import "FFOptionsContext.h"

@interface FFPlay()<FFAudioControllerDelegate>
@property(nonatomic,strong) FFAudioFrame* currentAudioFrame;
@property(nonatomic,assign) FFTimeContext ffContext;
@property(nonatomic,assign) double lastPostPosition;

@property(nonatomic,assign) BOOL framedrop;
@end

@implementation FFPlay

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        self.state = [[FFState alloc]init];
		self.position = 0.0f;
		self.lastPostPosition = 0.0f;

		self.framedrop = [FFOptionsContext defaultOptions].framedrop;

        [self.audioController registerAudioSession];
        [self setupObservers];
    }
    
    return self;
}

- (void)setupObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSeekingByVideo:)
                                                 name:kFFPlaySeekingVideoDidCompletedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateSeekingByAudio:)
                                                 name:kFFPlaySeekingAudioDidCompletedNotification
                                               object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(readyToPlay:)
												 name:kFFPlayReadyToPlayNotificationKey
											   object:nil];
}

- (void)setUrl:(NSString *)url
{
    _url = url;
    
    if(!url) return;

    self.decoder = [[FFDecoder alloc]initWithContentURL:url
                                                channel:self.audioController.numOutputChannels
											 sampleRate:self.audioController.sampleRate];
}

- (void)play
{
	if(!self.decoder.state.readyToDecode)
	{
		[CommonUtil showMessage:nil message:@"loading..."];
		 return;
	}

	self.state.playing = 1;

	[self.decoder startDecoder];
	
	if(self.decoder.audioEnable)
	{
		[self.audioController play];
	}

	if(self.decoder.videoEnable)
	{
		[self updateTimestamp];
		[self tick];
	}
}

- (void)pause
{
	if(!self.decoder.state.readyToDecode)
	{
		[CommonUtil showMessage:nil message:@"loading..."];
		return;
	}
	
    self.state.paused = 1;

    if(self.decoder.audioEnable)
	{
		[self.audioController pause];
	}

	if(self.decoder.videoEnable)
	{
		[self.decoder pause];
	}
}

- (void)seekToTime:(void(^)(void))block
{
	if(self.state.seeking) return;

	self.state.seeking  = 1;

	if(self.decoder.audioEnable)
    {
        self.currentAudioFrame = nil;
        [self.audioController pause];
    }

	if(block)
	{
		block();
	}

	FFSeekContext* seekCtx = [FFSeekContext shareContext];
	seekCtx.seek_start_time = CFAbsoluteTimeGetCurrent();

	if(self.state.endOfFile)
	{
		self.state.endOfFile = 0;
		self.state.playing   = 1;
		
        if(self.decoder.videoEnable)
        {
            [self tick];
        }
	}
}

- (void)seekToTimeByRatio:(float)ratio
{
	@weakify(self)
	[self seekToTime:^{
		@strongify(self)
		[self.decoder seekToTimeByRatio:ratio];
	}];
}

- (void)seekToTimeByValue:(NSTimeInterval)time
{
	@weakify(self)
	[self seekToTime:^{
		@strongify(self)
		[self.decoder seekToTime:time];
	}];
}

- (void)updateTimestamp
{
    FFTimeContext ctx = self.ffContext;
    ctx.frame_timer =  [NSDate date].timeIntervalSince1970;
    if(self.state.paused)
    {
        //paused no matter if seeking
        ctx.frame_timer = [NSDate date].timeIntervalSince1970 + ctx.actual_delay;
		ctx.audio_pts_drift = ctx.audio_pts - [NSDate date].timeIntervalSince1970;
    }
    else
    {
        //inital or seeking
        ctx.frame_last_delay = 0.0f;
        ctx.frame_last_pts   = 0.0f;
        ctx.audio_pts        = 0.0f;
        ctx.audio_duration   = 0.0f;
        ctx.actual_delay     = 0.0f;

		ctx.audio_pts_drift = [NSDate date].timeIntervalSince1970;
    }
    self.ffContext = ctx;
}

- (void)checkBuffering
{
	if(self.state.snapshot)
	{
		[self showSnapshot];
	}
}

- (BOOL)endOfFile
{
    return [self.decoder isEndOfFile];
}

- (void)tick
{
    if(!self.decoder.videoEnable) return;
	if(self.state.destroyed) return;

    //seeking
	if(self.state.seeking) return;
	
    //end of file
    if([self endOfFile])
    {
        self.state.endOfFile = 1;
		self.position = self.decoder.duration + self.decoder.startTime;
		
        [self pause];
        LOG_INFO(@"FFPlayerStateEndOfFile...");
        return;
    }
    
	if(self.state.paused) return;
    
    //playing
    double actual_delay, delay, sync_threshold, ref_clock, diff;
    FFVideoFrame* frame = [self.decoder.videoDecoder getFrameAsync];
    
    if(!frame)
    {
//        LOG_INFO(@"getFrameAsync is null...");
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC);
        dispatch_after(time, dispatch_get_main_queue(), ^(void){
            [self tick];
        });
        
        return;
    }

    FFTimeContext ctx = self.ffContext;
    
    delay = frame.position - ctx.frame_last_pts;
    if(delay <= 0 || delay >= 1.0)
    {
        delay = ctx.frame_last_delay;
    }
    
    ctx.frame_last_delay = delay;
    ctx.frame_last_pts   = frame.position;

	ref_clock = ctx.audio_pts_drift + [NSDate date].timeIntervalSince1970;

    diff = frame.position - ref_clock;
    
    sync_threshold = delay > 0.01 ? delay : 0.01;
    if(fabs(diff) < 10.0)
    {
        if(diff <= -sync_threshold)
        {
            delay = 0;
        }
        else if(diff >= sync_threshold)
        {
            delay = 2*delay;
        }
    }
    
    ctx.frame_timer += delay;
    actual_delay = ctx.frame_timer - [NSDate date].timeIntervalSince1970;
    ctx.actual_delay = actual_delay;
    
    if(actual_delay < 0.001)
    {
        actual_delay = 0.001;
    }

    self.ffContext = ctx;

	if(self.framedrop)
	{
		FFVideoFrame* nextFrame = [self.decoder.videoDecoder topFrame];
		if(nextFrame)
		{
			double duration = nextFrame.position - frame.position;
			if(isnan(duration) || duration <=0 || duration > 10.0)
			{
				//max_frame_duration
				duration = frame.duration;
			}

			double time = [NSDate date].timeIntervalSince1970;
			if(time - 0.1 >= ctx.frame_timer + duration)
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					[self tick];
				});

				return;
			}
		}
	}

	//log
//    LOG_DEBUG(@"begin~~~~~~~~~~~~~~");
//    LOG_DEBUG(@"video pts:  %f",frame.position);
//    LOG_DEBUG(@"audio pts:  %f",ref_clock);
//    LOG_DEBUG(@"video duration:  %f",frame.duration);
//    LOG_DEBUG(@"audio duration:  %f",ctx.audio_duration);
//    LOG_DEBUG(@"calculate delay:  %f",delay);
//    LOG_DEBUG(@"actual delay:  %f",actual_delay);
//    LOG_DEBUG(@"end~~~~~~~~~~~~~~");

	[self.ffMovie render:frame];
	[self updatePositionByVideo:frame.position];

	dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, actual_delay * NSEC_PER_SEC);
	dispatch_after(time, dispatch_get_main_queue(), ^(void){
		[self tick];
	});
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kFrameRenderedNotificationKey
                                                        object:nil];
}

#pragma mark -- FFAudioControllerDelegate
- (void)audioController:(FFAudioController *)audioController
          outputData:(float *)outputData
      numberOfFrames:(UInt32)numberOfFrames
    numberOfChannels:(UInt32)numberOfChannels
{
    if([self endOfFile])
    {
        self.state.endOfFile = 1;
        self.position = self.decoder.duration;
        [self.audioController pause];
        return;
    }
    
    if(!self.state.playing || self.state.seeking || self.state.destroyed)
    {
        memset(outputData, 0, numberOfFrames * numberOfChannels * sizeof(float));
        return;
    }
    
    @autoreleasepool
    {
        while (numberOfFrames > 0)
        {
            if(!self.currentAudioFrame)
            {
                self.currentAudioFrame = [self.decoder.audioDecoder getFrameAsync];
            }

            if(!self.currentAudioFrame)
            {
                memset(outputData, 0, numberOfFrames * numberOfChannels * sizeof(float));
                return;
            }
            
			FFAudioFrame* frame = self.currentAudioFrame;
			const Byte * bytes = (Byte *)frame.samples.bytes + frame.outputOffset;
			const NSUInteger bytesLeft    = frame.length - frame.outputOffset;
			const NSUInteger frameSizeOf  = numberOfChannels * sizeof(float);
			const NSUInteger bytesToCopy  = MIN(numberOfFrames * frameSizeOf, bytesLeft);
			const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;

			memcpy(outputData, bytes, bytesToCopy);
			numberOfFrames -= framesToCopy;
			outputData += framesToCopy * numberOfChannels;

			FFTimeContext ctx = self.ffContext;
			ctx.audio_duration = frame.duration;
			ctx.audio_pts = frame.position;
			ctx.audio_pts_drift = frame.position - [NSDate date].timeIntervalSince1970;

            if (bytesToCopy < bytesLeft)
            {
                frame.outputOffset += bytesToCopy;
            }
            else
            {
                self.currentAudioFrame.samples = nil;
                self.currentAudioFrame = nil;
            }

            self.ffContext = ctx;
			[self updatePositionByAudio:frame.position];
        }
    }
}

#pragma mark -- kFFPlaySeekingVideoDidCompletedNotification
- (void)updateSeekingByVideo:(NSNotification *)notification
{
    NSDictionary* dict = notification.userInfo;
    if(!dict) return;
    id obj = dict[kFFPlayVideoNotificationKey];
    
    if(obj && obj == self.decoder.videoDecoder)
    {
        [self updateSeeking];
    }
}

#pragma mark -- kFFPlaySeekingAudioDidCompletedNotification
- (void)updateSeekingByAudio:(NSNotification *)notification
{
    NSDictionary* dict = notification.userInfo;
    if(!dict) return;
    id obj = dict[kFFPlayAudioNotificationKey];
    
    if(obj && obj == self.decoder.audioDecoder)
    {
        [self updateSeeking];
    }
}

#pragma mark -- kFFPlayReadyToPlayNotificationKey
- (void)readyToPlay:(NSNotification *)notification
{
	if(!self.state.playing)
	{
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self play];
		});
	}
}

#pragma mark -- show snapshot
- (void)showSnapshot
{
	if(!self.state.snapshot) return;
	self.state.snapshot = 0;

	FFVideoFrame* frame = [self.decoder.videoDecoder topFrame];
	if(!frame) return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.ffMovie render:frame];
	});
}

- (void)updateSeeking
{
	if(self.state.seeking)
	{
		FFSeekContext* seekCtx = [FFSeekContext shareContext];

		BOOL completed = NO;
		if(!self.decoder.videoEnable && seekCtx.audio_seek_completed)
		{
			completed = YES;
		}
		else if(!self.decoder.audioEnable && seekCtx.video_seek_completed)
		{
			completed = YES;
		}
		else if(seekCtx.audio_seek_completed && seekCtx.video_seek_completed)
		{
			completed = YES;
		}

		if(completed)
		{
			seekCtx.video_seek_completed = 0;
			seekCtx.drop_vframe_count  = 0;
			seekCtx.drop_vPacket_count = 0;

			seekCtx.audio_seek_completed = 0;
			seekCtx.drop_aframe_count  = 0;
			seekCtx.drop_aPacket_count = 0;

			[self updateTimestamp];
			self.state.seeking = 0;
			LOG_INFO(@"all seek complete...");

			[self play];

            [[NSNotificationCenter defaultCenter] postNotificationName:kFFSeekCompletedNotificationKey
                                                                object:nil];
		}
	}
}

- (void)updatePositionByVideo:(float)position
{
	if(!self.decoder.audioEnable && self.decoder.videoEnable)
	{
		if(position > 0)
		{
			self.position = position;
		}
		else
		{
			self.position = 0;
		}
	}
}

- (void)updatePositionByAudio:(float)position
{
	if(self.decoder.audioEnable)
	{
		if(position > 0)
		{
			self.position = position;
		}
		else
		{
			self.position = 0;
		}
	}
}

- (void)setPosition:(double)position
{
	position = position - self.decoder.startTime;
    
	if(_position != position)
	{
		_position = position;
		float duration = self.decoder.duration;

		if(position <= 0.001 || fabs(position - self.decoder.duration) <= 0.001)
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
									  @(position), @"time",
									  @(duration), @"duration",
									  nil];
				[[NSNotificationCenter defaultCenter] postNotificationName:kFFPeriodicTimeNotificationKey object:self userInfo:info];
			});
		}
		else
		{
			NSTimeInterval currentTime = CFAbsoluteTimeGetCurrent();
			if (currentTime - self.lastPostPosition >= 1.0)
			{
				self.lastPostPosition = currentTime;
				dispatch_async(dispatch_get_main_queue(), ^{
					NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
										  @(position), @"time",
										  @(duration), @"duration",
										  nil];
					[[NSNotificationCenter defaultCenter] postNotificationName:kFFPeriodicTimeNotificationKey object:self userInfo:info];
				});
			}
		}
	}
}

- (FFMovie *)ffMovie
{
    if(!_ffMovie)
    {
        _ffMovie = [[FFMovie alloc]init];
    }
    
    return _ffMovie;
}

- (FFAudioController *)audioController
{
    if(!_audioController)
    {
        _audioController = [FFAudioController controller];
        _audioController.delegate = self;
    }
    return _audioController;
}

- (void)destroy
{
	if(!self.state.destroyed)
	{
		self.state.destroyed = 1;

		if(self.decoder)
		{
			[self.decoder destroy];
		}
	}
}

- (void)dealloc
{
	[self destroy];
    self.currentAudioFrame = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	LOG_DEBUG(@"%@ release...",[self class]);
}

@end
