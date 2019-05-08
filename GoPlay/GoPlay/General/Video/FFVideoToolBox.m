//
//  FFVideoToolBox.m
//  GoPlay
//
//  Created by dKingbin on 2018/8/11.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "FFVideoToolBox.h"
#import <VideoToolbox/VideoToolbox.h>
#import <VideoToolbox/VTErrors.h>
#import "FFVideoDecoder.h"

#import "libavformat/avc.h"
#include "libavutil/intreadwrite.h"

@interface FFVideoToolBox()
{
    VTDecompressionSessionRef _vt_session;
    CMFormatDescriptionRef _format_description;
    
@public
    OSStatus _decode_status;
    CVImageBufferRef _decode_output;

	volatile int flag;
}

@property(nonatomic,strong) FFVideoDecoderModel* model;
@property(nonatomic,assign) BOOL vtSessionToken;
@property(nonatomic,assign) BOOL needConvertNALSize3To4;
@property(nonatomic,assign) BOOL needConvertAnnexBtoAvcc;

@property(nonatomic,strong) NSData* vpsData;
@property(nonatomic,strong) NSData* spsData;
@property(nonatomic,strong) NSData* ppsData;
@end

@implementation FFVideoToolBox

+ (instancetype)decoderWithModel:(FFVideoDecoderModel*)model
{
    return [[self alloc]initWithModel:model];
}

- (instancetype)initWithModel:(FFVideoDecoderModel*)model
{
    self = [super init];
    
    if(self)
    {
        self.model = model;
		self->flag = 0;
    }
    
    return self;
}

- (BOOL)trySetupVTSession
{
    if (!self.vtSessionToken)
    {
        NSError * error = [self setupVTSession];
        if (!error)
        {
            self.vtSessionToken = YES;
        }
    }
    return self.vtSessionToken;
}

- (NSError *)setupVTSession
{
    NSError * error;
    
    enum AVCodecID codec = self.model.codecContex->codec_id;
    uint8_t * extradata = self.model.codecContex->extradata;
    int extradata_size  = self.model.codecContex->extradata_size;

	CMVideoCodecType format_id = 0;
	BOOL isHevcSupported = false;
	switch (codec) {
		case AV_CODEC_ID_HEVC:
			format_id = kCMVideoCodecType_HEVC;
			if (@available(iOS 11.0, *))
			{
				isHevcSupported = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC);
			}
			else
			{
				// Fallback on earlier versions
				isHevcSupported = false;
			}

			if (!isHevcSupported)
			{
				error = [NSError errorWithDomain:@"undefine format error" code:-1 userInfo:nil];
				return error;
			}
			break;

		case AV_CODEC_ID_H264:
			format_id = kCMVideoCodecType_H264;
			break;

		default:
			error = [NSError errorWithDomain:@"undefine format error" code:-1 userInfo:nil];
			return error;
	}

    if (format_id == kCMVideoCodecType_H264
		|| format_id == kCMVideoCodecType_HEVC)
    {
        if (extradata_size < 7 || extradata == NULL)
        {
            error = [NSError errorWithDomain:@"extradata error" code:-1 userInfo:nil];
            return error;
        }
        
        if (extradata[0] == 1)
        {
            //avcc/hvcc
            if (extradata[4] == 0xFE)
            {
                extradata[4] = 0xFF;
                self.needConvertNALSize3To4 = YES;
            }

            self->_format_description = CreateFormatDescription(format_id,
																self.model.codecContex->width,
																self.model.codecContex->height,
																extradata,
																extradata_size);
            
            if (self->_format_description == NULL)
            {
                error = [NSError errorWithDomain:@"create format description error" code:-1 userInfo:nil];
                return error;
            }
            
			error = [self setupAttributes];
            return error;
        }
        else
        {
            //Annex-B
            if (AV_RB32(extradata) == 0x00000001 || AV_RB24(extradata) == 0x000001)
            {
               int ret;
               self.needConvertAnnexBtoAvcc = YES;
               if(codec == AV_CODEC_ID_H264)
               {
                   //AVCDecoderConfigurationRecord
                   ret = [self ff_h264_sps_pps:extradata length:extradata_size];

                   if(ret == 0)
                   {
                       const uint8_t* const parameterSetPointers[2] = { self.spsData.bytes, self.ppsData.bytes};
                       const size_t parameterSetSizes[2] = { self.spsData.length, self.ppsData.length };

                       OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                                             2, //param count
                                                                                             parameterSetPointers,
                                                                                             parameterSetSizes,
                                                                                             4, //nal start code size
                                                                                             &_format_description);
                       if(status == noErr)
                       {
                           error = [self setupAttributes];
                           return error;
                       }
                   }
               }
               else if(codec == AV_CODEC_ID_HEVC)
               {
				   //HEVCDecoderConfigurationRecord
                   ret = [self ff_hevc_vps_sps_pps:extradata length:extradata_size];
                   
                   const uint8_t* const parameterSetPointers[3] = { self.vpsData.bytes, self.spsData.bytes, self.ppsData.bytes};
                   const size_t parameterSetSizes[3] = { self.vpsData.length, self.spsData.length, self.ppsData.length };
                   
                   if (@available(iOS 11.0, *))
                   {
                       OSStatus status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(kCFAllocatorDefault,
                                                                                             3, //param count
                                                                                             parameterSetPointers,
                                                                                             parameterSetSizes,
                                                                                             4, //nal start code size
                                                                                             NULL,
                                                                                             &_format_description);
                       if(status == noErr)
                       {
                           error = [self setupAttributes];
                           return error;
                       }
                   }
               }
                
                error = [NSError errorWithDomain:@"deal extradata error" code:-1 userInfo:nil];
                return error;
            }
            
            error = [NSError errorWithDomain:@"deal extradata error" code:-1 userInfo:nil];
            return error;
        }
    }
    else
    {
        error = [NSError errorWithDomain:@"not h264 error" code:-1 userInfo:nil];
        return error;
    }
    
    return error;
}

- (NSError*) setupAttributes
{
	NSError* error = NULL;

	CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(NULL,
                                                             0,
                                                             &kCFTypeDictionaryKeyCallBacks,
                                                             &kCFTypeDictionaryValueCallBacks);

	//When the video_full_range_flag syntax element is not present,
	//the value of video_full_range_flag shall be inferred to be equal to 0.
    cf_dict_set_int32(attrs,
                      kCVPixelBufferPixelFormatTypeKey,
                      kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange);

	cf_dict_set_int32(attrs, kCVPixelBufferWidthKey, self.model.codecContex->width);
	cf_dict_set_int32(attrs, kCVPixelBufferHeightKey, self.model.codecContex->height);

	VTDecompressionOutputCallbackRecord outputCallbackRecord;
	outputCallbackRecord.decompressionOutputCallback = outputCallback;
	outputCallbackRecord.decompressionOutputRefCon = (__bridge void *)self;

	OSStatus status = VTDecompressionSessionCreate(kCFAllocatorDefault,
												   self->_format_description,
												   NULL,
												   attrs,
												   &outputCallbackRecord,
												   &self->_vt_session);

	if (status != noErr)
	{
		error = [NSError errorWithDomain:@"create session error" code:-1 userInfo:nil];
		return error;
	}
	CFRelease(attrs);

	return error;
}

- (void)flushPacket:(AVPacket)packet
{
	BOOL needflush;
	self->flag = kVTDecodeFrame_DoNotOutputFrame;
	[self sendPacket:packet needFlush:&needflush];
	self->flag = 0;
}

- (BOOL)sendPacket:(AVPacket)packet needFlush:(BOOL *)needFlush
{
    BOOL setupResult = [self trySetupVTSession];
    if (!setupResult) return NO;
    [self cleanDecodeInfo];
    
    BOOL result = NO;
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status = noErr;

	uint8_t* demux_buffer = NULL;
	AVIOContext* pb = NULL;
	int demux_size = 0;

    if(self.needConvertAnnexBtoAvcc)
    {
        av_packet_split_side_data(&packet);

        if (avio_open_dyn_buf(&pb) < 0)
        {
            status = -1900;
        }
        else
        {
			ff_avc_parse_nal_units(pb, packet.data, packet.size);
            demux_size = avio_close_dyn_buf(pb, &demux_buffer);

            status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                        demux_buffer,
                                                        demux_size,
                                                        kCFAllocatorNull,
                                                        NULL,
                                                        0,
                                                        demux_size,
                                                        FALSE,
                                                        &blockBuffer);
        }
    }
	else if (self.needConvertNALSize3To4)
    {
        if (avio_open_dyn_buf(&pb) < 0)
        {
            status = -1900;
        }
        else
        {
            uint32_t nal_size;
            uint8_t * end = packet.data + packet.size;
            uint8_t * nal_start = packet.data;
            while (nal_start < end)
            {
                nal_size = (nal_start[0] << 16) | (nal_start[1] << 8) | nal_start[2];
                avio_wb32(pb, nal_size);
                nal_start += 3;
                avio_write(pb, nal_start, nal_size);
                nal_start += nal_size;
            }

            demux_size = avio_close_dyn_buf(pb, &demux_buffer);
            status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
														demux_buffer,
														demux_size,
														kCFAllocatorNull,
														NULL,
														0,
														packet.size,
														FALSE,
														&blockBuffer);
        }
    }
    else
    {
        status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
													packet.data,
													packet.size,
													kCFAllocatorNull,
													NULL,
													0,
													packet.size,
													FALSE,
													&blockBuffer);
    }
    
    if (status == kCMBlockBufferNoErr)
    {
        CMSampleBufferRef sampleBuffer = NULL;
        
        status = CMSampleBufferCreate(kCFAllocatorDefault,
                                      blockBuffer,
                                      TRUE,
                                      0,
                                      0,
                                      self->_format_description,
                                      1,
                                      0,
                                      NULL,
                                      0,
                                      NULL,
                                      &sampleBuffer);
        
        if (status == noErr)
        {
            status = VTDecompressionSessionDecodeFrame(self->_vt_session, sampleBuffer, self->flag, NULL, 0);

			if (status == noErr)
			{
				if (self->_decode_status == noErr && self->_decode_output != NULL)
				{
					result = YES;
				}
				else if(self->flag == 0 && self->_decode_output == NULL)
				{
					LOG_ERROR(@"failed to decode frame, status=%d",(int)self->_decode_status);
				}
			}
			else
			{
				if (status == kVTInvalidSessionErr)
				{
					*needFlush = YES;
				}

				LOG_ERROR(@"failed to decode frame, status=%d",(int)status);
			}
        }
        
        if (sampleBuffer)
        {
            CFRelease(sampleBuffer);
        }
    }
    
    if (blockBuffer)
    {
        CFRelease(blockBuffer);
    }

	if(demux_size)
	{
		av_free(demux_buffer);
	}

    return result;
}

-(int) ff_h264_sps_pps:(const uint8_t *)data length:(int)len
{
    if (len > 6)
    {
        /* check for H.264 start code */
        if (AV_RB32(data) == 0x00000001 || AV_RB24(data) == 0x000001)
        {
            uint8_t *buf=NULL, *end, *start;
            uint32_t sps_size=0, pps_size=0;
            uint8_t *sps=0, *pps=0;
            
            int ret = ff_avc_parse_nal_units_buf(data, &buf, &len);
            if (ret < 0)
                return ret;
            start = buf;
            end = buf + len;
            
            /* look for sps and pps */
            while (end - buf > 4)
            {
                uint32_t size;
                uint8_t nal_type;
                size = FFMIN(AV_RB32(buf), (uint32_t)(end - buf - 4));
                buf += 4;
                nal_type = buf[0] & 0x1f;
                
                if (nal_type == 7)
                {
                    /* SPS */
                    sps = buf;
                    sps_size = size;
                }
                else if (nal_type == 8)
                {
                    /* PPS */
                    pps = buf;
                    pps_size = size;
                }
                
                buf += size;
            }
            
            if (!sps || !pps ||
                sps_size < 4 ||
                sps_size > UINT16_MAX ||
                pps_size > UINT16_MAX)
                return -1;
            
            self.spsData = [NSData dataWithBytes:sps length:sps_size];
            self.ppsData = [NSData dataWithBytes:pps length:pps_size];
        }
    }
    else
    {
        return -1;
    }
    
    return 0;
}

-(int) ff_hevc_vps_sps_pps:(const uint8_t *)data length:(int)len
{
    if (len > 6)
    {
        /* check for H.264 start code */
        if (AV_RB32(data) == 0x00000001 || AV_RB24(data) == 0x000001)
        {
            uint8_t *buf=NULL, *end, *start;
            uint32_t vps_size=0, sps_size=0, pps_size=0;
            uint8_t *vps=0, *sps=0, *pps=0;
            
            int ret = ff_avc_parse_nal_units_buf(data, &buf, &len);
            if (ret < 0)
                return ret;
            start = buf;
            end = buf + len;
            
            /* look for sps and pps */
            while (end - buf > 4)
            {
                uint32_t size;
                uint8_t nal_type;
                size = FFMIN(AV_RB32(buf), (uint32_t)(end - buf - 4));
                nal_type = (buf[4] >> 1) & 0x3f;
                buf += 4;
                
                if (nal_type == 32)
                {
                    /* VPS */
                    vps = buf;
                    vps_size = size;
                }
                else if (nal_type == 33)
                {
                    /* SPS */
                    sps = buf;
                    sps_size = size;
                }
                else if (nal_type == 34)
                {
                    /* PPS */
                    pps = buf;
                    pps_size = size;
                }
                
                buf += size;
            }
            
            if (!sps || !pps || !vps ||
                sps_size < 4 ||
                sps_size > UINT16_MAX ||
                pps_size > UINT16_MAX ||
                vps_size > UINT16_MAX)
                return -1;
            
            self.vpsData = [NSData dataWithBytes:vps length:vps_size];
            self.spsData = [NSData dataWithBytes:sps length:sps_size];
            self.ppsData = [NSData dataWithBytes:pps length:pps_size];
        }
    }
    else
    {
        return -1;
    }
    
    return 0;
}

- (CVImageBufferRef)imageBuffer
{
    if (self->_decode_status == noErr && self->_decode_output != NULL)
    {
        return self->_decode_output;
    }
    
    return NULL;
}

- (void)cleanVTSession
{
    if (self->_format_description)
    {
        CFRelease(self->_format_description);
        self->_format_description = NULL;
    }
    
    if (self->_vt_session)
    {
        VTDecompressionSessionWaitForAsynchronousFrames(self->_vt_session);
        VTDecompressionSessionInvalidate(self->_vt_session);
        CFRelease(self->_vt_session);
        self->_vt_session = NULL;
    }
	self.needConvertAnnexBtoAvcc = NO;
    self.needConvertNALSize3To4 = NO;
    self.vtSessionToken = NO;
}

- (void)cleanDecodeInfo
{
    self->_decode_status = noErr;
    self->_decode_output = NULL;
}

- (void)flush
{
    [self cleanVTSession];
    [self cleanDecodeInfo];
}

static void outputCallback(void * decompressionOutputRefCon,
						   void * sourceFrameRefCon,
						   OSStatus status,
						   VTDecodeInfoFlags infoFlags,
						   CVImageBufferRef imageBuffer,
						   CMTime presentationTimeStamp,
						   CMTime presentationDuration)
{
    @autoreleasepool
    {
        FFVideoToolBox * videoToolBox = (__bridge FFVideoToolBox *)decompressionOutputRefCon;
        videoToolBox->_decode_status = status;
        videoToolBox->_decode_output = imageBuffer;
        
        if (imageBuffer != NULL)
        {
            CVPixelBufferRetain(imageBuffer);
        }
    }
}

static CMFormatDescriptionRef CreateFormatDescription(CMVideoCodecType codec_type, int width, int height, const uint8_t * extradata, int extradata_size)
{
    CMFormatDescriptionRef format_description = NULL;
    OSStatus status;
    
    CFMutableDictionaryRef par = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef atoms = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef extensions = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    // CVPixelAspectRatio
    cf_dict_set_int32(par, CFSTR("HorizontalSpacing"), 0);
    cf_dict_set_int32(par, CFSTR("VerticalSpacing"), 0);
    
    // SampleDescriptionExtensionAtoms
	switch (codec_type) {
		case kCMVideoCodecType_H264:
			cf_dict_set_data(atoms, CFSTR("avcC"), (uint8_t *)extradata, extradata_size);
			break;
		case kCMVideoCodecType_HEVC:
			cf_dict_set_data(atoms, CFSTR("hvcC"), (uint8_t *)extradata, extradata_size);
			break;
		default:
			break;
	}

    // Extensions
    cf_dict_set_string(extensions, CFSTR ("CVImageBufferChromaLocationBottomField"), "left");
    cf_dict_set_string(extensions, CFSTR ("CVImageBufferChromaLocationTopField"), "left");
    cf_dict_set_boolean(extensions, CFSTR("FullRangeVideo"), FALSE);
    cf_dict_set_object(extensions, CFSTR ("CVPixelAspectRatio"), (CFTypeRef *)par);
    cf_dict_set_object(extensions, CFSTR ("SampleDescriptionExtensionAtoms"), (CFTypeRef *)atoms);
    
    status = CMVideoFormatDescriptionCreate(NULL, codec_type, width, height, extensions, &format_description);
    
    CFRelease(extensions);
    CFRelease(atoms);
    CFRelease(par);
    
    if (status != noErr)
	{
        return NULL;
    }
    return format_description;
}

static void cf_dict_set_data(CFMutableDictionaryRef dict, CFStringRef key, uint8_t * value, uint64_t length)
{
    CFDataRef data;
    data = CFDataCreate(NULL, value, (CFIndex)length);
    CFDictionarySetValue(dict, key, data);
    CFRelease(data);
}

static void cf_dict_set_int32(CFMutableDictionaryRef dict, CFStringRef key, int32_t value)
{
    CFNumberRef number;
    number = CFNumberCreate(NULL, kCFNumberSInt32Type, &value);
    CFDictionarySetValue(dict, key, number);
    CFRelease(number);
}

static void cf_dict_set_string(CFMutableDictionaryRef dict, CFStringRef key, const char * value)
{
    CFStringRef string;
    string = CFStringCreateWithCString(NULL, value, kCFStringEncodingASCII);
    CFDictionarySetValue(dict, key, string);
    CFRelease(string);
}

static void cf_dict_set_boolean(CFMutableDictionaryRef dict, CFStringRef key, BOOL value)
{
    CFDictionarySetValue(dict, key, value ? kCFBooleanTrue: kCFBooleanFalse);
}

static void cf_dict_set_object(CFMutableDictionaryRef dict, CFStringRef key, CFTypeRef *value)
{
    CFDictionarySetValue(dict, key, value);
}

- (void)dealloc
{
    [self flush];
    
	LOG_DEBUG(@"%@ release...",[self class]);
}

@end
