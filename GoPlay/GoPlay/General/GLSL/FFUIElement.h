//
//  FFUIElement.h
//  GoPlay
//
//  Created by dKingbin on 2019/5/8.
//  Copyright © 2019 dKingbin. All rights reserved.
//

#import "FFOutput.h"
#import <UIKit/UIKit.h>

//from GPUImage/GPUImageUIElement
@interface FFUIElement : FFOutput
- (instancetype)initWithView:(UIView *)inputView;
- (instancetype)initWithLayer:(CALayer *)inputLayer;

- (CGSize)layerSizeInPixels;
- (void)update;
- (void)updateUsingCurrentTime;
- (void)updateWithTimestamp:(NSTimeInterval)frameTime;
@end
