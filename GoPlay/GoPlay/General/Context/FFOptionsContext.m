//
//  FFOptionsContext.m
//  GoPlay
//
//  Created by dKingbin on 2019/5/9.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import "FFOptionsContext.h"

@implementation FFOptions
@end

@implementation FFOptionsContext

+(FFOptions*) defaultOptions
{
	static FFOptions* options;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		options = [[FFOptions alloc]init];
		options.framedrop = YES;
		options.videotoolbox = YES;
		options.maxAudioSeekInterval = 0.01;
		options.maxVideoSeekInterval = 0.01;
		options.maxInterruptTimeout  = 10;
	});

	return options;
}

@end
