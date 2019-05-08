//
//  VideoView.h
//  GoPlay
//
//  Created by dKingbin on 2018/11/20.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TipsView.h"

@interface VideoView : UIView
@property(nonatomic,copy) void(^didGoBack)(void);
@property(nonatomic,copy) void(^didPlay)(void);
@property(nonatomic,copy) void(^didVR)(void);
@property(nonatomic,copy) void(^didFilter)(void);
@property(nonatomic,copy) void(^didSeek)(float);
@property(nonatomic,copy) void(^didSeeking)(float);
@property(nonatomic,copy) void(^didUpdateVolume)(float);

@property(nonatomic,copy) void(^didHorizontalStartPan)(void);
@property(nonatomic,copy) void(^didHorizontalPanning)(float);
@property(nonatomic,copy) void(^didHorizontalEndPan)(void);

@property(nonatomic,assign) BOOL isPlay;
@property(nonatomic,assign) BOOL isPanning;
@property(nonatomic,assign) BOOL isDragging;
@property(nonatomic,assign) float volume;

@property(nonatomic,strong) UILabel* timeLabel;
@property(nonatomic,strong) TipsView* tipsView;

- (void)updateTime:(float)time duration:(float)duration;
- (void)updateSliderValue:(float)value;

- (void)disablePanGesture;
- (void)enablePanGesture;
@end
