//
//  FFFrameUtil.hpp
//  GoPlay
//
//  Created by dKingbin on 2018/9/28.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#ifndef FFFrameUtil_hpp
#define FFFrameUtil_hpp

#include <stdio.h>
#include <iostream>

#include "Golomb.hpp"
#include "BitBuffer.hpp"

#import "avformat.h"

namespace ffstl
{
	class FFFrameUtil
	{
	public:
		static bool ff_is_b_frame(const AVPacket* packet)
		{
			//predict the min size for ensure to get the correct data;
			//8 bytes for first_mb_in_slice
			//8 bytes for slice_type
			int min_size = 4 + 1 + 8 + 8;
			min_size = min_size <= packet->size ? min_size : packet->size;

			char* buffer = new char[min_size];
			memcpy(buffer, packet->data, min_size);

			std::shared_ptr<BitBuffer> bits = std::make_shared<BitBuffer>(buffer,min_size);

			if(min_size < 5) return false;

			//length
			bits->readBit(32);

			//forbidden_zero_bit
			//nal_ref_idc
			//nal_unit_type
			bits->readBit(8);

			//slice_layer_without_partitioning_rbsp
			//slice_header
			//first_mb_in_slice
			Golomb::read_ue(bits);

			//slice_type
			/*
			 const uint8_t ff_h264_golomb_to_pict_type[5] = {
			 	AV_PICTURE_TYPE_P, AV_PICTURE_TYPE_B, AV_PICTURE_TYPE_I,
			 	AV_PICTURE_TYPE_SP, AV_PICTURE_TYPE_SI
			 };
			 */
			return Golomb::read_ue(bits) == 0x01;
		}
	};
}


#endif /* FFFrameUtil_hpp */
