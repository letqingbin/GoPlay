//
//  FFAlphaBendFilter.h
//  GoPlay
//
//  Created by dKingbin on 2019/5/8.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import "FFFilter.h"

@interface FFAlphaBendFilter : FFFilter
// Mix ranges from 0.0 (only image 1) to 1.0 (only image 2), with 1.0 as the normal level
@property(nonatomic,assign) float mix; 
@end

