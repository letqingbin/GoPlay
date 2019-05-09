//
//  FFVideoDecoder.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/5.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFVideoDecoder.h"
#import "FFPacketQueue.h"
#import "FFFrameQueue.h"
#import "FFVideoToolBox.h"
#import "FFSeekContext.h"

#import "FFUtil.h"
#import "FFStreamParser.h"
#import "FFOptionsContext.h"
#import <VideoToolbox/VideoToolbox.h>

#include <stdlib.h>
#include <memory.h>
#import <Accelerate/Accelerate.h>

extern AVPacket flush_packet;

@implementation FFVideoDecoderModel
@end

@interface FFVideoDecoder()
{
    AVFrame* _temp_frame;

	//yuv
	float* _vdsp_src[3];
	unsigned char* _vdsp_output[3];

	//videotoolbox
	volatile bool vt_reset_session;
}
@property(nonatomic,strong) FFPacketQueue* packetQueue;
@property(nonatomic,strong) FFFrameQueue*  frameQueue;
@property(nonatomic,strong) FFVideoDecoderModel* model;
@property(nonatomic,strong) FFVideoToolBox* videoToolBox;

@property(nonatomic,assign) int maxDecodeFrameCount;
@property(nonatomic,assign) BOOL videoToolBoxDidOpen;

//videotoolbox
@property(nonatomic,strong) FFPacketQueue* bufferQueue;
@end

@implementation FFVideoDecoder

+ (instancetype)decoderWithModel:(FFVideoDecoderModel*)model
{
    return [[self alloc]initWithModel:model];
}

- (instancetype)initWithModel:(FFVideoDecoderModel*)model
{
    self = [super init];
    
    if(self)
    {
		self.state = [[FFState alloc]init];
		self->vt_reset_session = false;

        self.model = model;
        self.maxDecodeFrameCount = 3;
		[self setupObservers];
        [self setupCodecContext];
    }
    
    return self;
}

- (void)setupCodecContext
{    
    _temp_frame = av_frame_alloc();

    if (self.model.videoToolBoxEnable)
    {
        self.videoToolBox = [FFVideoToolBox decoderWithModel:self.model];
        
        if ([self.videoToolBox trySetupVTSession])
        {
            self.videoToolBoxDidOpen = YES;
            self.maxDecodeFrameCount = 20;

			self.bufferQueue = [FFPacketQueue packetQueueWithTimebase:self.model.timebase];
        }
        else
        {
			self.videoToolBoxDidOpen = NO;
            [self.videoToolBox flush];
            self.videoToolBox = nil;
        }
    }
    
    self.packetQueue = [FFPacketQueue packetQueueWithTimebase:self.model.timebase];
    self.frameQueue  = [FFFrameQueue queue];
}

- (void)setupObservers
{

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(onAppDidEnterBackground:)
												 name:UIApplicationDidEnterBackgroundNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(onAppWillEnterForeground:)
												 name:UIApplicationWillEnterForegroundNotification
											   object:nil];
}

- (void)putPacket:(AVPacket)packet
{
    NSTimeInterval duration = packet.duration * self.model.timebase;
    if (packet.duration <= 0 && packet.size > 0 && packet.data != flush_packet.data)
    {
        duration = 1.0 / self.model.fps;
    }

	if(isnan(duration))
	{
		duration = 1.0 / self.model.fps;
	}

    [self.packetQueue putPacket:packet duration:duration];
}

- (FFVideoFrame *)getFrameAsync
{
    return [self.frameQueue getFrameAsync];
}

- (FFVideoFrame *)topFrame
{
	return [self.frameQueue topFrame];
}

- (void)startDecodeThread
{
	self.state.playing = 1;
    [self decodeAsyncThread];
}

#pragma mark - async decode thread
- (void)decodeAsyncThread
{
	float maxVideoSeekInterval = [FFOptionsContext defaultOptions].maxVideoSeekInterval;
	while (YES)
	{
        if(self.state.destroyed) break;
        if(self.state.error) break;
        
		if(self.state.endOfFile && self.packetQueue.count < 0)
		{
			break;
		}

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
			[self.videoToolBox flush];
			self.state.flushed = 1;
			continue;
		}

		if(packet.stream_index < 0 || packet.data == NULL)
		{
			 continue;
		}
		if(self.state.destroyed) break;

		[self enqueueBufferPacket:&packet];

		FFSeekContext* seekCtx = [FFSeekContext shareContext];

		if(self.state.seeking
           && self.model.codecContex->codec_id == AV_CODEC_ID_H264)
		{
			if(!self.state.flushed)
			{
				av_packet_unref(&packet);
				continue;
			}

			bool is_b_frame = [FFUtil ff_is_b_frame:&packet];

			float time = (packet.pts + packet.duration) * self.model.timebase;

			if(is_b_frame
			   && time < seekCtx.seekToTime
			   && fabs(time - seekCtx.seekToTime) > maxVideoSeekInterval)
			{
				seekCtx.drop_vPacket_count++;
				av_packet_unref(&packet);
				continue;
			}
		}

		FFVideoFrame* frame = nil;
		@autoreleasepool {
			frame = [self getVideoFrameByPacket:&packet];
		}
		if(!frame)
		{
			av_packet_unref(&packet);
			continue;	//EAGAIN
		}

		if(self.state.seeking)
		{
			if(!self.state.flushed)
			{
				av_packet_unref(&packet);
				continue;
			}

			if(seekCtx.drop_vframe_count == 0
			   && seekCtx.drop_vPacket_count == 0)
			{
				seekCtx.video_seek_start_time = frame.position;
			}

            bool completed = false;
            float currentTime = frame.position;
            float theLastTimetamp = currentTime + frame.duration;
            if(theLastTimetamp >= self.model.duration)
            {
                completed = true;    //end of file
            }
            
            // currentTime duration seekToTime
            
            // currentTime ~ duration   $
            // duration ~ seekToTime
            // currentTime ~ seekTime   $
            
            if(!completed
               && theLastTimetamp <= seekCtx.seekToTime
               && fabs(theLastTimetamp - seekCtx.seekToTime) > maxVideoSeekInterval)
            {
                seekCtx.drop_vframe_count++;
                av_packet_unref(&packet);
                continue;
            }
            else
            {
                completed = true;
            }
            
			if(completed)
			{
				seekCtx.video_seek_completed = 1;

				LOG_INFO(@"seeking drop_vframe_count: %d,current time: %f, video_seek_start_time: %f, B packet: %d, duration: %f",
					  seekCtx.drop_vframe_count,
					  currentTime,
					  seekCtx.video_seek_start_time,
					  seekCtx.drop_vPacket_count,
					  CFAbsoluteTimeGetCurrent() - seekCtx.seek_start_time);

				//reset
				self.state.seeking = 0;
				self.state.flushed = 0;

				//notify ffplayer reset seeking
				[[NSNotificationCenter defaultCenter] postNotificationName:kFFPlaySeekingVideoDidCompletedNotification
																	object:nil
																  userInfo:@{kFFPlayVideoNotificationKey:self}];
			}
		}

		//dts 1 2 3 4 5 6 7 8 9
		//pts 1 2 3 5 4 6 8 7 9

		if (frame)
		{
			[self.frameQueue putSortFrame:frame];
		}

		av_packet_unref(&packet);
	}
}

- (FFVideoFrame *)getVideoFrameByPacket:(AVPacket *)packet
{
	FFVideoFrame* frame = nil;
	if(self.videoToolBoxDidOpen)
	{
		FFVideoFrameNV12 * videoFrame = nil;
		BOOL vtbEnable = [self.videoToolBox trySetupVTSession];
		if (vtbEnable)
		{
			if(self->vt_reset_session)
			{
				self->vt_reset_session = false;

				for (NSValue* value in self.bufferQueue.packets)
				{
					AVPacket pkt;
					[value getValue:&pkt];
					[self.videoToolBox flushPacket:pkt];
				}
			}

			BOOL needFlush = NO;
			BOOL result = [self.videoToolBox sendPacket:*packet needFlush:&needFlush];
			if (result)
			{
				videoFrame = [self videoFrameFromVideoToolBox:*packet];
			}
			else if (needFlush)
			{
				[self.videoToolBox flush];
				self->vt_reset_session = true;
				return nil;
			}
		}

		//keyframe
		videoFrame.keyframe = packet->flags & AV_PKT_FLAG_KEY;
		frame = videoFrame;
	}
	else
	{
		int ret = avcodec_send_packet(self.model.codecContex, packet);

		if(ret < 0)
		{
			if(ret != AVERROR(EAGAIN) && ret != AVERROR_EOF)
			{
				self.state.error = 1;
			}
		}
		else
		{
			while (ret >= 0)
			{
				ret = avcodec_receive_frame(self.model.codecContex, _temp_frame);
				if(ret < 0)
				{
					if(ret != AVERROR(EAGAIN) && ret != AVERROR_EOF)
					{
						self.state.error = 1;
					}
				}
				else
				{
					frame = [self videoFrameFromTempFrame:packet->size];
				}
			}
		}
	}

	return frame;
}

static NSData* copyFrameData(UInt8 *src, int linesize, int width, int height);

- (FFVideoFrame *)videoFrameFromTempFrame:(int)packetSize
{
    if (!_temp_frame->data[0] || !_temp_frame->data[1] || !_temp_frame->data[2]) return nil;
    FFVideoFrame* frame = [[FFVideoFrame alloc]init];

	//format
	frame.src_format = self.model.format;
	frame.dst_format = AV_PIX_FMT_YUV420P;

    //position
    frame.position = av_frame_get_best_effort_timestamp(_temp_frame)*self.model.timebase;
	frame.packetSize = packetSize;

    //duration
    const int64_t frame_duration = av_frame_get_pkt_duration(_temp_frame);
    if (frame_duration)
    {
        frame.duration = frame_duration * self.model.timebase;
        frame.duration += _temp_frame->repeat_pict * self.model.timebase * 0.5;
    }
    else
    {
        frame.duration = 1.0 / self.model.fps;
    }

	//height width
	frame.width  = self.model.codecContex->width;
	frame.height = self.model.codecContex->height;

    //rotate
    if(self.model.rotate == 0)
    {
        frame.rotateMode = FFRotationMode_R0;
    }
    else if(self.model.rotate == 90)
    {
        frame.rotateMode = FFRotationMode_R90;
    }
    else if(self.model.rotate == 180)
    {
        frame.rotateMode = FFRotationMode_R180;
    }
    else if(self.model.rotate == 270)
    {
        frame.rotateMode = FFRotationMode_R270;
    }

	//keyframe
	frame.keyframe = _temp_frame->key_frame;

	//shift 2bits
	//对于8bit的数据,仅需要将count的数量除以2,就可以在vDSP_vfltu16变成16bit,步长之类的不需要改变;
	if(self.model.format == AV_PIX_FMT_YUV420P10LE)
	{
		int yCount = (_temp_frame->linesize[0]*0.5) * _temp_frame->height;
		int uCount = (_temp_frame->linesize[1]*0.5) * (_temp_frame->height*0.5);
		int vCount = (_temp_frame->linesize[2]*0.5) * (_temp_frame->height*0.5);

		int yindex = 0;
		int uindex = 1;
		int vindex = 2;

		float ratio = 0.25;
		//yuv y
		{
			float* ySrc = self->_vdsp_src[yindex];
			if(ySrc == NULL)
			{
				self->_vdsp_src[yindex] = (float*)malloc(sizeof(float)*yCount);
				ySrc = self->_vdsp_src[yindex];
			}

			unsigned char* yOutput = self->_vdsp_output[yindex];
			if(yOutput == NULL)
			{
				self->_vdsp_output[yindex] = (unsigned char*)malloc(sizeof(unsigned char)*yCount);
				yOutput = self->_vdsp_output[yindex];
			}

			vDSP_vfltu16((UInt16*)_temp_frame->data[0], 1, ySrc, 1, yCount);
			vDSP_vsmul(ySrc, 1, &ratio, ySrc, 1, yCount);
			vDSP_vfixu8(ySrc, 1, yOutput, 1, yCount);

			frame.luma = copyFrameData(yOutput, _temp_frame->linesize[0]*0.5, frame.width, frame.height);
		}

		//yuv u
		{
			float* uSrc = self->_vdsp_src[uindex];
			if(uSrc == NULL)
			{
				self->_vdsp_src[uindex] = (float*)malloc(sizeof(float)*uCount);
				uSrc = self->_vdsp_src[uindex];
			}

			unsigned char* uOutput = self->_vdsp_output[uindex];
			if(uOutput == NULL)
			{
				self->_vdsp_output[uindex] = (unsigned char*)malloc(sizeof(unsigned char)*uCount);
				uOutput = self->_vdsp_output[uindex];
			}

			vDSP_vfltu16((UInt16*)_temp_frame->data[1], 1, uSrc, 1, uCount);
			vDSP_vsmul(uSrc, 1, &ratio, uSrc, 1, uCount);
			vDSP_vfixu8(uSrc, 1, uOutput, 1, uCount);

			frame.chromaB = copyFrameData(uOutput, _temp_frame->linesize[1]*0.5, frame.width*0.5, frame.height*0.5);
		}

		//yuv v
		{
			float* vSrc = self->_vdsp_src[vindex];
			if(vSrc == NULL)
			{
				self->_vdsp_src[vindex] = (float*)malloc(sizeof(float)*vCount);
				vSrc = self->_vdsp_src[vindex];
			}

			unsigned char* vOutput = self->_vdsp_output[vindex];
			if(vOutput == NULL)
			{
				self->_vdsp_output[vindex] = (unsigned char*)malloc(sizeof(unsigned char)*vCount);
				vOutput = self->_vdsp_output[vindex];
			}

			vDSP_vfltu16((UInt16*)_temp_frame->data[2], 1, vSrc, 1, vCount);
			vDSP_vsmul(vSrc, 1, &ratio, vSrc, 1, vCount);
			vDSP_vfixu8(vSrc, 1, vOutput, 1, vCount);

			frame.chromaR = copyFrameData(vOutput, _temp_frame->linesize[2]*0.5, frame.width*0.5, frame.height*0.5);
		}
	}
	else
	{
		//data
		frame.luma = copyFrameData(_temp_frame->data[0],
								   _temp_frame->linesize[0],
								   frame.width,
								   frame.height);

		frame.chromaB = copyFrameData(_temp_frame->data[1],
									  _temp_frame->linesize[1],
									  frame.width*0.5,
									  frame.height*0.5);

		frame.chromaR = copyFrameData(_temp_frame->data[2],
									  _temp_frame->linesize[2],
									  frame.width*0.5,
									  frame.height*0.5);
	}

    return frame;
}

static NSData* copyFrameData(UInt8 *src, int linesize, int width, int height)
{
	width = MIN(linesize, width);
    NSMutableData *md = [NSMutableData dataWithLength: width * height];
    Byte *dst = (Byte*)md.mutableBytes;
    for (NSUInteger i = 0; i < height; ++i)
    {
        memcpy(dst, src, width);
        dst += width;
        src += linesize;
    }
    
    return md;
}

- (FFVideoFrameNV12 *)videoFrameFromVideoToolBox:(AVPacket)packet
{
    CVPixelBufferRef imageBuffer = [self.videoToolBox imageBuffer];
    if (imageBuffer == NULL) return nil;
    
    //data
    FFVideoFrameNV12 * frame = [[FFVideoFrameNV12 alloc]init];
    frame.pixelBuffer = imageBuffer;
    frame.width  = self.model.codecContex->width;
    frame.height = self.model.codecContex->height;
	frame.src_format = self.model.format;
    frame.dst_format = AV_PIX_FMT_NV12;
    
    //rotate
    if(self.model.rotate == 0)
    {
        frame.rotateMode = FFRotationMode_R0;
    }
    else if(self.model.rotate == 90)
    {
        frame.rotateMode = FFRotationMode_R90;
    }
    else if(self.model.rotate == 180)
    {
        frame.rotateMode = FFRotationMode_R180;
    }
    else if(self.model.rotate == 270)
    {
        frame.rotateMode = FFRotationMode_R270;
    }
    
    //position
    if (packet.pts != AV_NOPTS_VALUE)
    {
        frame.position = packet.pts * self.model.timebase;
    }
    else
    {
        frame.position = packet.dts;
    }
    frame.packetSize = packet.size;
    
    //duration
    const int64_t frame_duration = packet.duration;
    if (frame_duration)
    {
        frame.duration = frame_duration * self.model.timebase;
    }
    else
    {
        frame.duration = 1.0 / self.model.fps;
    }

    return frame;
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

#pragma mark -- UIApplicationDidEnterBackgroundNotification
- (void)onAppDidEnterBackground:(UIApplication*)app
{
	self.state.paused = 1;
}

-(void)onAppWillEnterForeground:(UIApplication*)app
{
	self.state.paused = 0;
}

- (void)enqueueBufferPacket:(AVPacket*)packet
{
	if(!self.videoToolBoxDidOpen) return;

	const int max_pkt_queue_size = 350;
	bool idr_based_identified = false;
	if(ff_avpacket_is_idr(packet) == true)
	{
		idr_based_identified = true;
	}

	if(ff_avpacket_i_or_idr(packet, idr_based_identified) == true)
	{
		[self.bufferQueue flush];
	}
	else if(self.bufferQueue.count >= max_pkt_queue_size)
	{
		[self.bufferQueue flush];
	}

	AVPacket pkt;
	av_copy_packet(&pkt,packet);

	float duration = pkt.duration * self.model.timebase;
	[self.bufferQueue putPacket:pkt duration:duration];
}

- (void)destroy
{
    if(!self.state.destroyed)
    {
        self.state.destroyed = 1;

        [self.frameQueue destroy];
        [self.packetQueue destroy];

		self.frameQueue  = NULL;
		self.packetQueue = NULL;
		
		if(self.videoToolBoxDidOpen)
		{
			[self.bufferQueue destroy];
			self.bufferQueue = NULL;
		}
    }
}

- (void)dealloc
{
    [self destroy];

	if(_temp_frame)
	{
		av_free(_temp_frame);
		_temp_frame = NULL;
	}

	if(_vdsp_src)
	{
		for(int i=0;i<3;i++)
		{
			if(_vdsp_src[i])
			{
				free(_vdsp_src[i]);
				_vdsp_src[i] = NULL;
			}
		}
	}

	if(_vdsp_output)
	{
		for(int i=0;i<3;i++)
		{
			if(_vdsp_output[i])
			{
				free(_vdsp_output[i]);
				_vdsp_output[i] = NULL;
			}
		}
	}

	[[NSNotificationCenter defaultCenter] removeObserver:self];

	LOG_DEBUG(@"%@ release...",[self class]);
}

@end
