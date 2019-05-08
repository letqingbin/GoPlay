//
//  BitBuffer.hpp
//  GoPlay
//
//  Created by dKingbin on 2018/9/24.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#ifndef BitBuffer_hpp
#define BitBuffer_hpp

#include <stdio.h>
#include <iostream>
#include <bitset>
#include <math.h>
#include <cassert>

namespace ffstl
{
    class BitBuffer
    {
    public:
        BitBuffer(void* _ptr,size_t _len) :
        buffer_((unsigned char*)_ptr)
        , pos_(0)
        , length_(_len*8)
        {
        }
        
        int readBit(size_t len = 1);
		void skip(size_t len);

        ~BitBuffer()
        {
            delete[] buffer_;
            
            buffer_ = NULL;
            pos_ = 0;
            length_ = 0;
        }
        
        size_t length() const
        {
            return length_;
        }

		bool isFull() const
		{
			return length_ == pos_;
		}

    private:
        BitBuffer(const BitBuffer& _rhs);
        BitBuffer& operator= (const BitBuffer& _rhs);
        
    protected:
        unsigned char* buffer_;
        size_t pos_;
        size_t length_;
    };
}

#endif /* BitBuffer_hpp */
