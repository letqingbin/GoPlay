//
//  Golomb.hpp
//  GoPlay
//
//  Created by dKingbin on 2018/9/23.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#ifndef GlomobDecoder_hpp
#define GlomobDecoder_hpp

#include <stdio.h>
#include <iostream>
#include <math.h>

#include "BitBuffer.hpp"

namespace ffstl
{
    //test https://en.wikipedia.org/wiki/Exponential-Golomb_coding
    //9.1 Parsing process for Exp-Golomb codes
    class Golomb
    {
    public:
        Golomb()
        {}
        
        //codeNum = 2^leadingzerobits − 1 + read_bits( leadingZeroBits )
        static int read_ue(std::shared_ptr<BitBuffer> buffer)
        {
            int result = 0;
            int leadingzerobits = 0;
            int tail = 0;

			while (!buffer->isFull())
			{
				int32_t bit = buffer->readBit(1);
				if(bit == 0)
				{
					leadingzerobits++;
				}
				else
				{
					break;
				}
			}

            for(int i=0;i<leadingzerobits;i++)
            {
				if(buffer->isFull()) return -1;

                int32_t bit = buffer->readBit(1);
                tail = tail << 1 | bit;
            }
            
            return result = pow(2, leadingzerobits) - 1 + tail;
        }
        
        static int read_se(std::shared_ptr<BitBuffer> buffer)
        {
            int result = read_ue(buffer);

			if(result == -1) return -1;

            if(result & 0x01)
            {
                result = (result + 1) >> 1;
            }
            else
            {
                result = - result >> 1;
            }
            
            return result;
        }
    };
}

#endif /* Golomb */
