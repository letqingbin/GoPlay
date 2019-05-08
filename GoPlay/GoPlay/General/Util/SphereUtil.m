//
//  SphereUtil.m
//  GoPlay
//
//  Created by dKingbin on 2019/3/27.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import "SphereUtil.h"

@implementation SphereUtil

+ (GLKVector3)projectOntoSurfaceByPoint:(GLKVector3)touchPoint
								 radius:(float)radius
								 center:(GLKVector3)center
{
    GLKVector3 P = GLKVector3Subtract(touchPoint, center);
    
    // Flip the y-axis because pixel coords increase toward the bottom.
//    P = GLKVector3Make(P.x, P.y * -1, P.z);
    
    float radius2 = radius * radius;
    float length2 = P.x*P.x + P.y*P.y;
    
    if (length2 <= radius2)
    {
        P.z = sqrt(radius2 - length2);
    }
    else
    {
        /*
         P.x *= radius / sqrt(length2);
         P.y *= radius / sqrt(length2);
         P.z = 0;
         */
        P.z = radius2 / (2.0 * sqrt(length2));
        float length = sqrt(length2 + P.z * P.z);
        P = GLKVector3DivideScalar(P, length);
    }
    
    return GLKVector3Normalize(P);
}

+ (GLKQuaternion)computeQuaterionByStartQuaternion:(GLKQuaternion)start
                                            Anchor:(GLKVector3)anchor
                                           current:(GLKVector3)current
{
    GLKQuaternion result;
    GLKVector3 axis = GLKVector3CrossProduct(anchor, current);

	/*
	Since we're using float variables, there may be precision issues: dot may return a value slightly greater than 1,
	 and acos will return nan, which means an invalid float. The consequence is that our rotation matrix will be all messed,
	 and usually our object will just disappear from the screen! To remedy this, we cap the value with a maximum of 1.0.
	 */
    float dot   = MIN(1.0, GLKVector3DotProduct(anchor, current));
    float angle = acosf(dot);
    
    GLKQuaternion temp_quatertion = GLKQuaternionMakeWithAngleAndVector3Axis(angle * 2, axis);
    temp_quatertion = GLKQuaternionNormalize(temp_quatertion);
    
    result = GLKQuaternionMultiply(temp_quatertion, start);
    return result;
}

+ (float)sphereRadius
{
	float width = [UIScreen mainScreen].bounds.size.width;
	return width/3.0;
}

+ (GLKVector3)sphereCenter
{
	float width = [UIScreen mainScreen].bounds.size.width;
	float height = [UIScreen mainScreen].bounds.size.height;
	return GLKVector3Make(width/2.0, height/2.0,0.0);
}

@end
