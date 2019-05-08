//
//  FFStreamParser.h
//  GoPlay
//
//  Created by dKingbin on 2018/9/3.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#ifndef FFStreamParser_H_
#define FFStreamParser_H_

#import "avformat.h"

__unused static double FFStreamGetTimebase(AVStream * stream, double default_timebase)
{
	double timebase;
	if (stream->time_base.den > 0 && stream->time_base.num > 0) {
		timebase = av_q2d(stream->time_base);
	} else {
		timebase = default_timebase;
	}
	return timebase;
}

__unused static double FFStreamGetFPS(AVStream * stream, double timebase)
{
	double fps;
	if (stream->avg_frame_rate.den > 0 && stream->avg_frame_rate.num > 0) {
		fps = av_q2d(stream->avg_frame_rate);
	} else if (stream->r_frame_rate.den > 0 && stream->r_frame_rate.num > 0) {
		fps = av_q2d(stream->r_frame_rate);
	} else {
		fps = 1.0 / timebase;
	}
	return fps;
}

__unused static int FFStreamGetRotate(AVStream* stream)
{
	int rotate = 0;

	AVDictionaryEntry* tag = NULL;
	tag = av_dict_get(stream->metadata, "rotate", tag, 0);
	if(tag == NULL)
	{
		rotate = 0;
	}
	else
	{
		rotate = atoi(tag->value) % 360;
	}

	return rotate;
}

__unused static float FFStreamGetDuration(AVStream* stream, double timebase, double default_duration)
{
	float duration = 0;
	if(stream->duration == AV_NOPTS_VALUE)
	{
		duration = default_duration;
	}
	else
	{
		duration = stream->duration*timebase;
	}

	return duration;
}

__unused static enum AVColorRange FFStreamGetColorRange(AVStream *stream)
{
	return stream->codecpar->color_range;
}

static inline int ff_get_nal_units_type(const uint8_t * const data) {
	return   data[4] & 0x1f;
}

static uint32_t bytesToInt(uint8_t* src) {
	uint32_t value;
	value = (uint32_t)((src[0] & 0xFF)<<24|(src[1]&0xFF)<<16|(src[2]&0xFF)<<8|(src[3]&0xFF));
	return value;
}

__unused static bool ff_avpacket_is_idr(const AVPacket* pkt) {

	int state = -1;

	if (pkt->data && pkt->size >= 5) {
		int offset = 0;
		while (offset >= 0 && offset + 5 <= pkt->size) {
			void* nal_start = pkt->data+offset;
			state = ff_get_nal_units_type(nal_start);
			if (state == 5)
			{
				return true;
			}
			offset+=(bytesToInt(nal_start) + 4);
		}
	}
	return false;
}

__unused static bool ff_avpacket_is_key(const AVPacket* pkt) {
	if (pkt->flags & AV_PKT_FLAG_KEY) {
		return true;
	} else {
		return false;
	}
}

__unused static bool ff_avpacket_i_or_idr(const AVPacket* pkt,bool isIdr) {
	if (isIdr == true) {
		return ff_avpacket_is_idr(pkt);
	} else {
		return ff_avpacket_is_key(pkt);
	}
}

#endif /* Header_h */
