//
//  SphereUtil.h
//  GoPlay
//
//  Created by dKingbin on 2019/3/27.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SphereUtil : NSObject

+ (GLKVector3)projectOntoSurfaceByPoint:(GLKVector3)touchPoint
								 radius:(float)radius
								 center:(GLKVector3)center;

+ (GLKQuaternion)computeQuaterionByStartQuaternion:(GLKQuaternion)start
                                            Anchor:(GLKVector3)anchor
                                           current:(GLKVector3)current;

+ (float)sphereRadius;
+ (GLKVector3)sphereCenter;

@end

NS_ASSUME_NONNULL_END
