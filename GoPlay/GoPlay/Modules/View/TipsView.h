//
//  TipsView.h
//  GoPlay
//
//  Created by dKingbin on 2018/11/20.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
	tt_volume = 0,
	tt_brightness ,
	tt_seektime_forward ,
	tt_seektime_backward,
} TipsType;

@interface TipsView : UIView
- (void)showAt:(UIView*)view;
- (void)hide;

- (float)currentValue;
- (void)updateValue:(float)value;
- (void)updateTime:(float)time duration:(float)duration;

@property(nonatomic,assign) TipsType type;
@end
