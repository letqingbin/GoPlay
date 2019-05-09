//
//  FFAudioDecoder.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/4.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFAudioDecoder.h"
#import "FFFrameQueue.h"
#import "FFPacketQueue.h"
#import "swscale.h"
#import "swresample.h"

#import <Accelerate/Accelerate.h>
#import "FFSeekContext.h"
#import "FFOptionsContext.h"

extern AVPacket flush_packet;

@implementation FFAudioDecoderModel
@end

@interface FFAudioDecoder()
{
    SwrContext * _audio_swr_context;
    AVFrame* _temp_frame;
    void * _audio_swr_buffer;
    int _audio_swr_buffer_size;
}

@property(nonatomic,strong) FFAudioDecoderModel *model;
@property(nonatomic,strong) FFPacketQueue * packetQueue;
@property(nonatomic,strong) FFFrameQueue *frameQueue;
@end

@implementation FFAudioDecoder

+ (instancetype)decoderWithModel:(FFAudioDecoderModel*)model
{
    return [[self alloc]initWithModel:model];
}

- (instancetype)initWithModel:(FFAudioDecoderModel*)model
{
    self = [super init];
    
    if(self)
    {
        self.state = [[FFState alloc]init];
        
        self.model = model;
        _temp_frame = av_frame_alloc();
        
        [self setupSwsContext];
        self.packetQueue = [FFPacketQueue packetQueueWithTimebase:self.model.timebase];
    }
    
    return self;
}

- (void)setupSwsContext
{
    _audio_swr_context = swr_alloc_set_opts(NULL,
                                            av_get_default_channel_layout(self.model.numOutputChannels),
                                            AV_SAMPLE_FMT_S16,
                                            self.model.sampleRate,
                                            av_get_default_channel_layout(self.model.codecContex->channels),
                                            self.model.codecContex->sample_fmt,
                                            self.model.codecContex->sample_rate,
                                            0,
                                            NULL);
    
    int result = swr_init(_audio_swr_context);
    if (result || !_audio_swr_context)
    {
        if (_audio_swr_context)
        {
            swr_free(&_audio_swr_context);
        }
    }
}

- (void)startDecodeThread
{
    self.state.playing = 1;
    float maxAudioSeekInterval = [FFOptionsContext defaultOptions].maxAudioSeekInterval;
    while (YES)
    {
        if(self.state.destroyed) break;
        
        if(self.state.endOfFile) break;
        
        if(self.state.paused && !self.state.seeking)
        {
            [NSThread sleepForTimeInterval:0.1];
            continue;
        }
        
        AVPacket packet = [self.packetQueue getPacketSync];
        
        if(packet.data == flush_packet.data)
        {
            avcodec_flush_buffers(self.model.codecContex);
            [self.frameQueue flush];
            self.state.flushed = 1;
            continue;
        }
        
        FFSeekContext* seekCtx = [FFSeekContext shareContext];

		bool completed = false;
        if(self.state.seeking)
        {
            if(!self.state.flushed) continue;
            if(seekCtx.drop_aframe_count == 0
               && seekCtx.drop_aPacket_count == 0)
            {
                seekCtx.audio_seek_start_time = packet.pts * self.model.timebase;
            }

			float theLastTimetamp = (packet.pts + packet.duration) * self.model.timebase;
			if(theLastTimetamp >= self.model.duration)
			{
				completed = true;
			}

            if(!completed
			   && theLastTimetamp <= seekCtx.seekToTime
               && fabs(theLastTimetamp - seekCtx.seekToTime) > maxAudioSeekInterval)
            {
                seekCtx.drop_aPacket_count++;
				av_packet_unref(&packet);
                continue;
            }
			else
			{
				completed = true;
			}
        }
        
        if(self.state.destroyed) break;
        
        int result = avcodec_send_packet(self.model.codecContex, &packet);
        if (result < 0 && result != AVERROR(EAGAIN) && result != AVERROR_EOF)
        {
            break;
        }
        
        while (result >= 0)
        {
            result = avcodec_receive_frame(self.model.codecContex, _temp_frame);
            
            if (result < 0)
            {
                break;
            }

			FFAudioFrame * frame = [self decode:packet.size];

            if(self.state.seeking)
            {
                if(!self.state.flushed) break;
                if(seekCtx.drop_aframe_count == 0
                   && seekCtx.drop_aPacket_count == 0)
                {
                    seekCtx.audio_seek_start_time = frame.position;
                }

                float time = frame.position + frame.duration;
                if(!completed
				   && time <= seekCtx.seekToTime
                   && fabs(time - seekCtx.seekToTime) > maxAudioSeekInterval)
                {
                    seekCtx.drop_aframe_count++;
					av_packet_unref(&packet);
                    continue;
                }
				else
				{
					completed = true;
				}

                if(completed)
                {
                    //wait for video signal
                    seekCtx.audio_seek_completed = 1;

                    LOG_INFO(@"seeking drop_aframe_count: %d,current time: %f, audio_start_time: %f, audio packet: %d, duration: %f",
                          seekCtx.drop_aframe_count,
                          time,
                          seekCtx.audio_seek_start_time,
                          seekCtx.drop_aPacket_count,
						  CFAbsoluteTimeGetCurrent() - seekCtx.seek_start_time);

                    //reset
                    self.state.seeking = 0;
                    self.state.flushed = 0;

                    //notify ffplayer reset seeking
                    [[NSNotificationCenter defaultCenter] postNotificationName:kFFPlaySeekingAudioDidCompletedNotification
                                                                        object:nil
                                                                      userInfo:@{kFFPlayAudioNotificationKey:self}];
                }
            }

            if (frame)
            {
                [self.frameQueue putFrame:frame];
            }
        }
        av_packet_unref(&packet);
    }
}

- (int)putPacket:(AVPacket)packet
{
    if (packet.data == NULL) return 0;
    
    NSTimeInterval duration = packet.duration * self.model.timebase;
    if (packet.duration <= 0 && packet.size > 0)
    {
        duration = packet.size / self.model.sampleRate;
    }

	if(isnan(duration))
	{
		duration = packet.size / self.model.sampleRate;
	}

    [self.packetQueue putPacket:packet duration:duration];
    
    return 0;
}

- (FFAudioFrame *)decode:(int)packetSize
{
    if (!_temp_frame->data[0]) return nil;
    
    int numberOfFrames;
    void * audioDataBuffer;
    
    if (_audio_swr_context)
    {
        const int ratio = MAX(1, self.model.sampleRate / self.model.codecContex->sample_rate)
        * MAX(1, self.model.numOutputChannels / self.model.codecContex->channels) * 2;

        int out_count = _temp_frame->nb_samples * ratio;
        const int buffer_size = av_samples_get_buffer_size(NULL,
                                                           self.model.numOutputChannels,
                                                           out_count,
                                                           AV_SAMPLE_FMT_S16,
                                                           1);

        if (!_audio_swr_buffer || _audio_swr_buffer_size < buffer_size)
        {
            _audio_swr_buffer_size = buffer_size;
            _audio_swr_buffer = realloc(_audio_swr_buffer, _audio_swr_buffer_size);
        }

        //音频重采样
		uint8_t** outputBuffer = (uint8_t**)&_audio_swr_buffer;
        numberOfFrames = swr_convert(_audio_swr_context,
                                     outputBuffer,
                                     out_count,
                                     (const uint8_t **)_temp_frame->data,
                                     _temp_frame->nb_samples);

        if (numberOfFrames < 0)
        {
            LOG_ERROR(@"failed to resample audio...");
            return nil;
        }

        //normal
        audioDataBuffer = _audio_swr_buffer;
    }
    else
    {
        if(self.model.codecContex->sample_fmt != AV_SAMPLE_FMT_S16)
        {
            LOG_ERROR(@"audio format error");
            return nil;
        }
        
        audioDataBuffer = _temp_frame->data[0];
        numberOfFrames = _temp_frame->nb_samples;
    }

    FFAudioFrame * audioFrame = [[FFAudioFrame alloc]init];
    
    @autoreleasepool
    {
		const NSUInteger numberOfElements = numberOfFrames * self.model.numOutputChannels;
		NSMutableData *data = [NSMutableData dataWithLength:numberOfElements * sizeof(float)];

		float scale = 1.0 / (float)INT16_MAX ;
		vDSP_vflt16((SInt16 *)audioDataBuffer, 1, data.mutableBytes, 1, numberOfElements);
		vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numberOfElements);

		audioFrame.position = av_frame_get_best_effort_timestamp(_temp_frame) * self.model.timebase;
		audioFrame.duration = av_frame_get_pkt_duration(_temp_frame) * self.model.timebase;
		audioFrame.samples  = data;
		audioFrame.packetSize = packetSize;
		audioFrame.outputOffset = 0;

		if (audioFrame.duration == 0)
		{
			// sometimes ffmpeg can't determine the duration of audio frame
			// especially of wma/wmv format
			// so in this case must compute duration
			audioFrame.duration = (float)audioFrame.length / (float)(sizeof(float) * self.model.numOutputChannels * self.model.sampleRate);
		}
    }
    
    return audioFrame;
}

- (FFFrameQueue *)frameQueue
{
    if(!_frameQueue)
    {
        _frameQueue = [FFFrameQueue queue];
    }
    
    return _frameQueue;
}

- (int)bufferSize
{
	return self.frameQueue.packetSize + self.packetQueue.size;
}

- (int)bufferCount
{
    return (int)self.frameQueue.count + (int)self.packetQueue.count;
}

- (double)bufferDuration
{
	return self.frameQueue.duration + self.packetQueue.duration;
}

- (BOOL)emtpy
{
    return self.frameQueue.count <= 0 && self.packetQueue.count <= 0;
}

- (void)flush
{
    [self.packetQueue flush];
    [self.frameQueue flush];
    
    [self putPacket:flush_packet];
}

- (void)seek
{
    self.state.seeking = 1;
    [self flush];
}

- (void)destroy
{
    if(!self.state.destroyed)
    {
        [self.state clearAllSates];
        self.state.destroyed = 1;

        [self.frameQueue destroy];
        [self.packetQueue destroy];
        
        self.frameQueue  = NULL;
        self.packetQueue = NULL;
    }
}

- (FFAudioFrame *)getFrameAsync
{
    return [self.frameQueue getFrameAsync];
}

- (void)dealloc
{
    [self destroy];

	if(_audio_swr_buffer)
	{
		free(_audio_swr_buffer);
		_audio_swr_buffer = NULL;
		_audio_swr_buffer_size = 0;
	}

	if(_audio_swr_context)
	{
		swr_free(&_audio_swr_context);
		_audio_swr_context = NULL;
	}

	if(_temp_frame)
	{
		av_free(_temp_frame);
		_temp_frame = NULL;
	}
	
	LOG_DEBUG(@"%@ release...",[self class]);
}

@end

