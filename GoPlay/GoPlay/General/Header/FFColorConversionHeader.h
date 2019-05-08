//
//  FFColorConversionHeader.h
//  GoPlay
//
//  Created by dKingbin on 2018/12/18.
//  Copyright © 2018 dKingbin. All rights reserved.
//

#ifndef FFColorConversionHeader_h
#define FFColorConversionHeader_h

// BT.2020
static const float kFFColorConversion2020[] = {
	1.168f, 1.168f, 1.168f,
	0.0f, -0.188f, 2.148f,
	1.683f, -0.652f, 0.0f,
};

// BT.709, which is the standard for HDTV.
static const float kFFColorConversion709[] = {
	1.164,    1.164,     1.164,
	0.0,      -0.213,    2.112,
	1.793,    -0.533,    0.0,
};

static const float kFFColorConversion601[] = {
	1.164,  1.164, 1.164,
	0.0,   -0.392, 2.017,
	1.596, -0.813, 0.0,
};

// BT.601 full range (ref: http://www.equasys.de/colorconversion.html)
static const float kFFColorConversion601FullRangeDefault[] = {
	1.0,    1.0,    1.0,
	0.0,    -0.343, 1.765,
	1.4,    -0.711, 0.0,
};

#endif /* FFColorConversionHeader_h */
