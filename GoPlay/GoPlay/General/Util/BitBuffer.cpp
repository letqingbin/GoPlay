//
//  BitBuffer.cpp
//  GoPlay
//
//  Created by dKingbin on 2018/9/24.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#include "BitBuffer.hpp"

namespace ffstl
{
	//big endian
	//datas(bits) read from left to right
    int BitBuffer::readBit(size_t len)
    {
        if(len <= 0) return -1;
        
        int value = 0;
        
        size_t nRead = length_ - pos_;
        nRead = std::min(nRead, len);

		for(int i=0;i<nRead;i++)
		{
			value <<= 1;

			size_t index_i = pos_ / 8;
			size_t index_j = pos_ % 8;

			uint8_t current = buffer_[index_i];

			if(current & (0x80 >> index_j))
			{
				value |= 1;
			}
			pos_++;
		}

        return value;
    }

	void BitBuffer::skip(size_t len)
	{
		if(len <= 0) return;

		size_t nRead = length_ - pos_;
		nRead = std::min(nRead, len);

		pos_ += nRead;
	}
}
