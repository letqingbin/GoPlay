//
//  FFVRFilter.h
//  GoPlay
//
//  Created by dKingbin on 2019/3/20.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import "FFFilter.h"
#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface FFVRFilter : FFFilter
@property(nonatomic,assign) GLKQuaternion currentQuaterion;
@end

NS_ASSUME_NONNULL_END
