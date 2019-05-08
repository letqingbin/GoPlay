//
//  FFDecoder.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/6.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFDecoder.h"

#import "FFHeader.h"

#import "avformat.h"
#import "FFSeekContext.h"
#import "FFStreamParser.h"

#import "FFVideoDecoder.h"
#import "FFAudioDecoder.h"

AVPacket flush_packet;

void FFmepgLog(void * context, int level, const char * format, va_list args)
{
#if DEBUG
	NSString * message = [[NSString alloc] initWithFormat:[NSString stringWithUTF8String:format] arguments:args];
	NSLog(@"FFmepgLog : %@", message);
#endif
}

NSError* FFCheckErrorCode(int result, NSUInteger errorCode)
{
	if (result < 0) {
		char * error_string_buffer = malloc(256);
		av_strerror(result, error_string_buffer, 256);
		NSString * error_string = [NSString stringWithFormat:@"ffmpeg code : %d, ffmpeg msg : %s", result, error_string_buffer];
		NSError * error = [NSError errorWithDomain:error_string code:errorCode userInfo:nil];
		return error;
	}
	return nil;
}

static int ffmpeg_interrupt_callback(void* ctx)
{
	FFDecoder* obj = (__bridge FFDecoder*)ctx;
	double timeout = fabs(CFAbsoluteTimeGetCurrent() - obj.interrupt_timeout);

	if(timeout >= kMaxInterruptTimeout)
	{
		LOG_INFO(@"ffmpeg_interrupt_callback, timeout : %f",timeout);

		if(obj.didInterruptCallback)
		{
			obj.didInterruptCallback();
		}

		return 1;
	}

	return 0;
}

@interface FFDecoder()
{
@public
	AVFormatContext * _format_context;
	AVCodecContext * _video_codec_context;
	AVCodecContext * _audio_codec_context;
}

@property(nonatomic,strong) NSOperationQueue * ffmpegOperationQueue;
@property(nonatomic,strong) NSInvocationOperation * openFileOperation;
@property(nonatomic,strong) NSInvocationOperation * readPacketOperation;
@property(nonatomic,strong) NSInvocationOperation * decodeVideoFrameOperation;
@property(nonatomic,strong) NSInvocationOperation * decodeAudioFrameOperation;

@property(nonatomic,strong) NSString* contentURL;

@property(nonatomic,assign) int videoStreamIndex;
@property(nonatomic,assign) int audioStreamIndex;

//video
@property(nonatomic,assign) NSTimeInterval videoTimebase;
@property(nonatomic,assign) NSTimeInterval videoFPS;
@property(nonatomic,assign) CGFloat videoAspect;
@property(nonatomic,assign) int videoFormat;
@property(nonatomic,assign) int rotate;
@property(nonatomic,assign) float videoDuration;

//audio
@property(nonatomic,assign) NSTimeInterval audioTimebase;
@property(nonatomic,assign) int audioFormat;

@property(nonatomic,assign) UInt32  numOutputChannels;
@property(nonatomic,assign) Float64 sampleRate;
@property(nonatomic,assign) float audioDuration;

//seek
@property(nonatomic,assign) float seekToTime;
@property(nonatomic,copy) void(^seekToCompleteHandler)(BOOL);
@end

@implementation FFDecoder

- (instancetype)initWithContentURL:(NSString *)contentURL
						   channel:(UInt32)numOutputChannels
						sampleRate:(Float64)sampleRate
{
	self = [super init];

	if(self)
	{
		self.contentURL = contentURL;
		self.state = [[FFState alloc]init];
        self.state.readyToDecode = 0;

		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
//            av_log_set_callback(FFmepgLog);
			av_register_all();
			avformat_network_init();

			av_init_packet(&flush_packet);
			flush_packet.data = (uint8_t *)&flush_packet;
			flush_packet.duration = 0;
		});

		self.videoStreamIndex = -1;
		self.audioStreamIndex = -1;

		self.numOutputChannels = numOutputChannels;
		self.sampleRate = sampleRate;

		self.duration = 0;

		self.didErrorCallback = ^{
			LOG_DEBUG(@"failed to load asset...");
		};

        [self setupOperationQueue];
	}

	return self;
}

- (void)seekToTimeByRatio:(float)ratio
{
    if(!self.state.readyToDecode) return;
    
	if(ratio <= 0) ratio = 0;
	if(ratio >= 1) ratio = 1;
	
	[self seekToTimeByRatio:ratio completeHandler:nil];
}

- (void)seekToTimeByRatio:(float)ratio completeHandler:(void (^)(BOOL finished))completeHandler
{
    if(!self.state.readyToDecode) return;
    
	float time = ratio * self.duration;
	[self seekToTime:time completeHandler:completeHandler];
}

- (void)seekToTime:(NSTimeInterval)time
{
    if(!self.state.readyToDecode) return;
    [self seekToTime:time completeHandler:nil];
}

- (void)seekToTime:(NSTimeInterval)time completeHandler:(void (^)(BOOL finished))completeHandler
{
    if(!self.state.readyToDecode) return;
    
    self.seekToTime = time;
    self.seekToCompleteHandler = completeHandler;

	LOG_DEBUG(@"start seek to time at : %f",self.seekToTime);

	self.state.seeking = 1;

    if(self.state.endOfFile)
    {
		[self.state clearAllSates];
		self.state.seeking = 1;

        [self setupReadPacketOperation];
    }
}

- (void)startDecoder
{
	self.state.playing = 1;
	[self setupReadPacketOperation]; 
}

- (void)pause
{
	self.state.paused = 1;
}

- (void)setupOperationQueue
{
	self.ffmpegOperationQueue = [[NSOperationQueue alloc] init];
	self.ffmpegOperationQueue.qualityOfService = NSQualityOfServiceUserInteractive;

	self.openFileOperation = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(openFormatContext) object:nil];
	self.openFileOperation.queuePriority = NSOperationQueuePriorityVeryHigh;
	self.openFileOperation.qualityOfService = NSQualityOfServiceUserInteractive;

	[self.ffmpegOperationQueue addOperation:self.openFileOperation];
}

- (void) openFormatContext
{
	[self openStream];
	if(self.state.error) return;

	[self openTracks];

	[self openVideoTrack];
	if(self.state.error) return;

	[self openAudioTrack];
	if(self.state.error) return;

	if(self.videoEnable)
	{
		FFVideoDecoderModel* videoParam = [[FFVideoDecoderModel alloc]init];
		videoParam.fps = self.videoFPS;
		videoParam.timebase = self.videoTimebase;
		videoParam.format   = self.videoFormat;
		videoParam.rotate   = self.rotate;
		videoParam.videoToolBoxEnable = YES;    //开启硬解码
		videoParam.codecContex = self->_video_codec_context;
		videoParam.duration    = self.videoDuration;
		self.videoDecoder = [FFVideoDecoder decoderWithModel:videoParam];
	}

	if(self.audioEnable)
	{
		FFAudioDecoderModel* audioParam = [[FFAudioDecoderModel alloc]init];
		audioParam.format = self.audioFormat;
		audioParam.timebase = self.audioTimebase;
		audioParam.sampleRate = self.sampleRate;		//from audio manager
		audioParam.numOutputChannels = self.numOutputChannels;	//from audio manager
		audioParam.duration  = self->_audioDuration;
		audioParam.codecContex = self->_audio_codec_context;
		self.audioDecoder = [FFAudioDecoder decoderWithModel:audioParam];
	}

    self.state.readyToDecode = 1;

    [[NSNotificationCenter defaultCenter] postNotificationName:kFFPlayReadyToPlayNotificationKey object:self userInfo:nil];
}

- (void)setupReadPacketOperation
{
	if (!self.readPacketOperation || self.readPacketOperation.isFinished)
	{
		self.readPacketOperation = [[NSInvocationOperation alloc] initWithTarget:self
																		selector:@selector(readPacketThread)
																		  object:nil];
		[self.ffmpegOperationQueue addOperation:self.readPacketOperation];
	}

	if (self.videoEnable)
	{
		if (!self.decodeVideoFrameOperation || self.decodeVideoFrameOperation.isFinished)
		{
			self.decodeVideoFrameOperation = [[NSInvocationOperation alloc] initWithTarget:self.videoDecoder
																			 selector:@selector(startDecodeThread)
																			   object:nil];
            [self.ffmpegOperationQueue addOperation:self.decodeVideoFrameOperation];
		}
	}

    if (self.audioEnable)
    {
        if (!self.decodeAudioFrameOperation || self.decodeAudioFrameOperation.isFinished)
        {
            self.decodeAudioFrameOperation = [[NSInvocationOperation alloc] initWithTarget:self.audioDecoder
                                                                                  selector:@selector(startDecodeThread)
                                                                                    object:nil];
            [self.ffmpegOperationQueue addOperation:self.decodeAudioFrameOperation];
        }
    }
}

- (void)readPacketThread
{
	NSAssert(![[NSThread currentThread] isMainThread], @"cannot decode at main thread!");

	AVPacket packet;
	while (YES)
	{
        if(self.state.destroyed || self.state.endOfFile) break;
        
		if(self.state.error)
        {
            LOG_ERROR(@"FFDecoderStateError");
            break;
        }

		if(self.state.seeking)
		{
			int ret = 0;
            int64_t ts = (int64_t)(self.seekToTime * AV_TIME_BASE);
			LOG_DEBUG(@"seek ts = %lld ",ts);

            ret = av_seek_frame(self->_format_context, -1, ts, AVSEEK_FLAG_BACKWARD);
            
			if(ret < 0)
			{
				self.state.error = 1;
				if(self.didErrorCallback)
				{
					self.didErrorCallback();
				}
				LOG_ERROR(@"failed to avformat_seek_file");
			}

			if(self.videoEnable)
			{
				[self.videoDecoder seek];
			}

			if(self.audioEnable)
			{
				[self.audioDecoder seek];
			}

            FFSeekContext* seekCtx = [FFSeekContext shareContext];
            seekCtx.seekToTime = self.seekToTime;
            
			[self.state clearAllSates];
			self.state.playing = 1;

			continue;
		}

		BOOL shouldBuffer = YES;
		if(self.videoEnable && [self.videoDecoder bufferCount] < 16)
		{
			shouldBuffer = NO;
		}

		if(self.audioEnable && [self.audioDecoder bufferCount] < 16)
		{
			shouldBuffer = NO;
		}

       if(shouldBuffer)
       {
		   float duration = 0.5;
		   if(self.videoEnable)
		   {
			   duration = [self.videoDecoder bufferDuration];
		   }

		   if(self.audioEnable)
		   {
			    float audioDuration = [self.audioDecoder bufferDuration];
			   duration = duration <= audioDuration ? duration : audioDuration;
		   }

           if(self.state.paused)
           {
			   duration = 0.8 * duration;
               [NSThread sleepForTimeInterval:duration];
           }
           else
           {
			   duration = 0.5 * duration;
               [NSThread sleepForTimeInterval:duration];
           }
		   
           continue;
       }

		self.interrupt_timeout = CFAbsoluteTimeGetCurrent();
		int ret = av_read_frame(self->_format_context, &packet);
		if(ret < 0)
		{
            if(ret == AVERROR_EOF)
            {
				self.state.endOfFile = 1;
                LOG_INFO(@"ffDeocder end of file....");
            }
			else
			{
				self.state.error = 1;
				if(self.didErrorCallback)
				{
					self.didErrorCallback();
				}
			}

            break;
		}

		if(packet.stream_index == self.videoStreamIndex && self.videoEnable)
		{
			[self.videoDecoder putPacket:packet];
		}
		else if(packet.stream_index == self.audioStreamIndex && self.audioEnable)
		{
			[self.audioDecoder putPacket:packet];
		}
	}
}

- (void)openStream
{
	NSError* error = nil;
	int reslut = 0;

	AVDictionary* options = NULL;
	NSString * URLString = self.contentURL;
	self->_format_context = avformat_alloc_context();

	if (!_format_context)
	{
		self.state.error = 1;
		if(self.didErrorCallback)
		{
			self.didErrorCallback();
		}

		error = [NSError errorWithDomain:@"failed to avformat_alloc_context" code:-1 userInfo:nil];
		return;
	}

	NSString * lowercaseURLString = [URLString lowercaseString];
    if ([lowercaseURLString hasPrefix:@"rtmp"] || [lowercaseURLString hasPrefix:@"rtsp"])
    {
        // There is total different meaning for 'timeout' option in rtmp
        // listen timeout
        av_dict_set(&options, "timeout", NULL, 0);
        
        //AVFMT_FLAG_NOBUFFER
        ///< Do not buffer frames when possible
        av_dict_set(&options, "fflags", "nobuffer", 0);
        
        //http
        av_dict_set(&options, "reconnect", "1", 0);
        
        //rtmp
//      av_dict_set(&options, "probesize", "3000000", 0);    		  //default 5000000byte
//      av_dict_set(&options, "max_analyze_duration", "2000000", 0);  //default 5seconds
        av_dict_set(&options, "tune", "zerolatency", 0);
		self->_format_context->fps_probe_size = 10;
    }

	if([lowercaseURLString hasPrefix:@"rtsp"])
	{
		av_dict_set(&options, "stimeout", "3000000", 0);
	}

	_format_context->interrupt_callback.callback = ffmpeg_interrupt_callback;
	_format_context->interrupt_callback.opaque = (__bridge void *)self;

	self.interrupt_timeout = CFAbsoluteTimeGetCurrent();
	reslut = avformat_open_input(&_format_context, URLString.UTF8String, NULL, &options);
	if(options)
	{
		av_dict_free(&options);
	}

	error = FFCheckErrorCode(reslut,1);
	if (error || !_format_context)
	{
		if (_format_context)
		{
			avformat_free_context(_format_context);
		}
	
		self.state.error = 1;
		if(self.didErrorCallback)
		{
			self.didErrorCallback();
		}

		return;
	}

	reslut = avformat_find_stream_info(_format_context, NULL);
	error = FFCheckErrorCode(reslut,2);
	if (error || !_format_context)
	{
		if (_format_context)
		{
			avformat_close_input(&_format_context);
		}

		self.state.error = 1;
		if(self.didErrorCallback)
		{
			self.didErrorCallback();
		}

		return;
	}
}

- (void)openTracks
{
	for (int i = 0; i < self->_format_context->nb_streams; i++)
	{
		AVStream * stream = self->_format_context->streams[i];
		switch (stream->codecpar->codec_type)
		{
			case AVMEDIA_TYPE_VIDEO:
			{
				self.videoStreamIndex = i;
			}
				break;
			case AVMEDIA_TYPE_AUDIO:
			{
				self.audioStreamIndex = i;
			}
				break;
			default:
				break;
		}
	}
}

- (void)openVideoTrack
{
	if (self.videoStreamIndex != -1
		&& (_format_context->streams[self.videoStreamIndex]->disposition & AV_DISPOSITION_ATTACHED_PIC) == 0)
	{
		AVCodecContext * codec_context = NULL;
		[self openStreamWithTrackIndex:self.videoStreamIndex codecContext:&codec_context domain:@"video"];
		if(self.state.error) return;

		self.videoEnable = YES;
		self.videoTimebase = FFStreamGetTimebase(_format_context->streams[self.videoStreamIndex], 0.00004);
		self.videoFPS    = FFStreamGetFPS(_format_context->streams[self.videoStreamIndex], self.videoTimebase);
		self.videoAspect = (CGFloat)codec_context->width / (CGFloat)codec_context->height;
		self.videoFormat = _format_context->streams[self.videoStreamIndex]->codecpar->format;
		self.rotate      = FFStreamGetRotate(_format_context->streams[self.videoStreamIndex]);
		self.videoDuration = FFStreamGetDuration(_format_context->streams[self.videoStreamIndex],self.videoTimebase,self.duration);

		self->_video_codec_context = codec_context;
	}
	else
	{
		self.videoEnable = NO;
	}
}

- (void)openAudioTrack
{
	if(self.audioStreamIndex != -1)
	{
		AVCodecContext* codec_context = NULL;
		[self openStreamWithTrackIndex:self.audioStreamIndex codecContext:&codec_context domain:@"audio"];
		if(self.state.error) return;

		self.audioEnable   = YES;
		self.audioTimebase = FFStreamGetTimebase(_format_context->streams[self.audioStreamIndex], 0.000025);
		self.audioFormat   = _format_context->streams[self.audioStreamIndex]->codecpar->format;
		self.audioDuration = FFStreamGetDuration(_format_context->streams[self.audioStreamIndex],self.audioTimebase,self.duration);
		self->_audio_codec_context = codec_context;
	}
	else
	{
		self.audioEnable = NO;
	}
}

- (void)openStreamWithTrackIndex:(int)trackIndex codecContext:(AVCodecContext **)codecContext domain:(NSString *)domain
{
	int result = 0;
	NSError * error = nil;

	AVStream * stream = _format_context->streams[trackIndex];

	AVCodecContext* codec_context = avcodec_alloc_context3(NULL);
	if (!codec_context)
	{
		error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@ codec context create error", domain]
									code:3
								userInfo:nil];
		self.state.error = 1;
		if(self.didErrorCallback)
		{
			self.didErrorCallback();
		}

		return;
	}

	result = avcodec_parameters_to_context(codec_context, stream->codecpar);
	error = FFCheckErrorCode(result, 3);
	if (error)
	{
		avcodec_free_context(&codec_context);

		self.state.error = 1;
		if(self.didErrorCallback)
		{
			self.didErrorCallback();
		}
		return;
	}
	av_codec_set_pkt_timebase(codec_context, stream->time_base);

	AVCodec* codec = avcodec_find_decoder(codec_context->codec_id);
	if (!codec)
	{
		avcodec_free_context(&codec_context);
		error = [NSError errorWithDomain:[NSString stringWithFormat:@"%@ codec not found decoder", domain]
									code:4
								userInfo:nil];
		self.state.error = 1;
		if(self.didErrorCallback)
		{
			self.didErrorCallback();
		}

		return;
	}
	codec_context->codec_id = codec->id;

	result = avcodec_open2(codec_context, codec, NULL);
	error = FFCheckErrorCode(result, 5);
	if (error)
	{
		avcodec_free_context(&codec_context);
		self.state.error = 1;
		if(self.didErrorCallback)
		{
			self.didErrorCallback();
		}

		return;
	}

	*codecContext = codec_context;
}

- (BOOL)isBufferEmtpy
{
	if(self.videoEnable && ![self.videoDecoder emtpy])
	{
		return NO;
	}

	if(self.audioEnable && ![self.audioDecoder emtpy])
	{
		return NO;
	}

	return YES;
}

- (BOOL)isEndOfFile
{
	return self.state.endOfFile && [self isBufferEmtpy];
}

- (float)duration
{
	if(!_format_context) return 0.0;
	int64_t duration = self->_format_context->duration;
	if(duration <= 0)
	{
		return 0;
	}

	return (float)duration / AV_TIME_BASE;
}

- (float)startTime
{
	if(AV_NOPTS_VALUE != _format_context->start_time)
	{
		return (float)_format_context->start_time / AV_TIME_BASE;
	}

	if(self.videoEnable)
	{
		AVStream* st = self->_format_context->streams[self->_videoStreamIndex];
		if(AV_NOPTS_VALUE != st->start_time)
		{
			return st->start_time * self.videoTimebase;
		}

		return 0;
	}

	if(self.audioEnable)
	{
		AVStream* st = self->_format_context->streams[self->_audioStreamIndex];
		if(AV_NOPTS_VALUE != st->start_time)
		{
			return st->start_time * self.audioTimebase;
		}

		return 0;
	}

	return 0;
}

- (void)destroy
{
    if(!self.state.destroyed)
    {
        self.state.destroyed = 1;
        
        if(self.videoEnable)
		{
			[self.videoDecoder destroy];
		}

		if(self.audioEnable)
		{
			[self.audioDecoder destroy];
		}

        self.videoDecoder = NULL;
        self.audioDecoder = NULL;

		[self closeOperations];
    }
}

- (void)closeOperations
{
	[self.ffmpegOperationQueue cancelAllOperations];
//	[self.ffmpegOperationQueue waitUntilAllOperationsAreFinished];

	self.openFileOperation = nil;
	self.readPacketOperation = nil;
	self.decodeVideoFrameOperation = nil;
	self.decodeAudioFrameOperation = nil;
}

- (void)dealloc
{
    [self destroy];

	if(_video_codec_context)
	{
		avcodec_close(_video_codec_context);
		_video_codec_context = NULL;
	}

	if(_audio_codec_context)
	{
		avcodec_close(_audio_codec_context);
		_audio_codec_context = NULL;
	}

	if(_format_context)
	{
		avformat_close_input(&_format_context);
		_format_context = NULL;
	}
	
	LOG_DEBUG(@"%@ release...",[self class]);
}

@end
