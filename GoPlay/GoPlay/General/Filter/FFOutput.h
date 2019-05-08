//
//  FFOutput.h
//  GoPlay
//
//  Created by dKingbin on 2018/8/9.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import "FFHeader.h"
@class FFFramebuffer;

@protocol FFInputProtocol <NSObject>
@optional
- (void) setInputFramebuffer:(FFFramebuffer*)framebuffer atIndex:(NSInteger)index;
- (void) setInputSize:(CGSize)size atIndex:(NSInteger)index;
- (void) setInputRotate:(FFRotationMode)mode atIndex:(NSInteger)index;
- (void) newFrameReadyAtTime:(NSTimeInterval)time atIndex:(NSInteger)index;
- (NSInteger)nextAvailableTextureIndex;
- (void) endProcess;
@end

@interface FFOutput : NSObject

@property(nonatomic,strong) FFFramebuffer* outputFramebuffer;
@property(nonatomic,strong) NSMutableArray* targets;
@property(nonatomic,strong) NSMutableArray* targetIndices;
@property(nonatomic,assign) CGSize inputTextureSize;

- (void) addTarget:(id<FFInputProtocol>)target;
- (void) addTarget:(id<FFInputProtocol>)target atIndex:(NSInteger)index;
- (void) removeTarget:(id<FFInputProtocol>)target;
- (void) removeAllTargets;

@end
