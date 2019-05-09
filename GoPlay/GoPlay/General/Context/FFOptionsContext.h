//
//  FFOptionsContext.h
//  GoPlay
//
//  Created by dKingbin on 2019/5/9.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FFOptions : NSObject

// default YES;
// when video pts behind audio pts, drop video frames;
@property(nonatomic,assign) BOOL framedrop;

// default YES;
// enable VideoToolBox
@property(nonatomic,assign) BOOL videotoolbox;

// default 0.01s
// audio seek interval
@property(nonatomic,assign) float maxAudioSeekInterval;

// default 0.01s
// video seek interval
@property(nonatomic,assign) float maxVideoSeekInterval;

// default 10s
// interrupt timeout
@property(nonatomic,assign) float maxInterruptTimeout;
@end

@interface FFOptionsContext : NSObject
+(FFOptions*) defaultOptions;
@end
