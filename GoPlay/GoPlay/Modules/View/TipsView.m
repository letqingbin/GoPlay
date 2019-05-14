//
//  TipsView.m
//  GoPlay
//
//  Created by dKingbin on 2018/11/20.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "TipsView.h"
#import "ColorUtil.h"
#import "CommonUtil.h"
#import "Masonry.h"
#import "ReactiveCocoa.h"

@interface TipsView()
@property(nonatomic,strong) UIImageView* logo;
@property(nonatomic,strong) UIProgressView* progressView;
@property(nonatomic,strong) UILabel* timeLabel;
@end

@implementation TipsView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		self.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.5];
		self.layer.cornerRadius = 2;
		self.layer.masksToBounds = YES;

		[self addSubviews];
		[self defineLayouts];
		[self setupObservers];
	}

	return self;
}

- (void)showAt:(UIView*)view
{
	if(!view)
	{
		view = [[UIApplication sharedApplication] delegate].window;
	}
	[self removeFromSuperview];

	self.hidden = NO;
	[view addSubview:self];
	[self mas_makeConstraints:^(MASConstraintMaker *make) {
		make.center.equalTo(view);
		make.size.mas_equalTo(CGSizeMake(170, 85));
	}];
}

- (void)hide
{
	self.hidden = YES;
	[self removeFromSuperview];
	self.progressView.progress = 0;
}

- (void)setType:(TipsType)type
{
	_type = type;
	if(type == tt_volume)
	{
		self.logo.image = [UIImage imageNamed:@"gg_volume_icon"];
	}
	else if(type == tt_brightness)
	{
		self.logo.image = [UIImage imageNamed:@"gg_brightness_icon"];
	}
	else if(type == tt_seektime_forward)
	{
		self.logo.image = [UIImage imageNamed:@"gg_forward_icon"];
	}
	else if(type == tt_seektime_backward)
	{
		self.logo.image = [UIImage imageNamed:@"gg_backward_icon"];
	}

	if(type == tt_volume || type == tt_brightness)
	{
		self.progressView.hidden = NO;
		self.timeLabel.hidden = YES;
	}
	else
	{
		self.progressView.hidden = YES;
		self.timeLabel.hidden = NO;
	}
}

- (void)updateValue:(float)value
{
	if(value > 1.0) value = 1.0;
	if(value < 0.0) value = 0.0;
	self.progressView.progress = value;
}

- (float)currentValue
{
	return self.progressView.progress;
}

- (void)updateTime:(float)time duration:(float)duration
{
	int t_time = time;
	int d_duration = duration;

	long t_min = t_time / 60;
	long t_sec = t_time % 60;
	long d_min = d_duration / 60;
	long d_sec = d_duration % 60;
	self.timeLabel.text = [NSString stringWithFormat:@"%02ld:%02ld/%02ld:%02ld", t_min, t_sec,d_min,d_sec];
}

- (void)addSubviews
{
	[self addSubview:self.logo];
	[self addSubview:self.progressView];
	[self addSubview:self.timeLabel];
}

- (void)defineLayouts
{
	[self.logo mas_makeConstraints:^(MASConstraintMaker *make) {
		make.centerX.equalTo(self);
		make.centerY.equalTo(self).offset(-10);
	}];

	[self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
		make.top.equalTo(self.logo.mas_bottom).offset(20);
		make.size.mas_equalTo(CGSizeMake(110, 2));
		make.centerX.equalTo(self);
	}];

	[self.timeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
		make.top.equalTo(self.logo.mas_bottom).offset(14);
		make.centerX.equalTo(self);
	}];
}

- (void)setupObservers
{
}

- (UIImageView *)logo
{
	if(!_logo)
	{
		_logo = [[UIImageView alloc]init];
	}
	return _logo;
}

- (UIProgressView *)progressView
{
	if(!_progressView)
	{
		_progressView = [[UIProgressView alloc]init];
		_progressView.tintColor = UIColor.whiteColor;
		_progressView.backgroundColor = [UIColor.whiteColor colorWithAlphaComponent:0.5];
	}
	return _progressView;
}

- (UILabel *)timeLabel
{
	if(!_timeLabel)
	{
		_timeLabel = [CommonUtil LabelWithTitle:@"00:00/00:00"
									  textColor:[UIColor whiteColor]
										bgColor:[UIColor clearColor]
										   font:14
								  textAlignment:NSTextAlignmentCenter
										   Bold:NO];
		_timeLabel.hidden = YES;
	}

	return _timeLabel;
}

@end
