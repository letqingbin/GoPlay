//
//  LoadingUtil.m
//  GoPlay
//
//  Created by dKingbin on 2018/7/18.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "LoadingUtil.h"
#import "LoadingView.h"
#import "Masonry.h"

extern float kLoadingWidth;
extern float kLoadingHeight;

@interface LoadingUtil()
@property(nonatomic,strong) UIView* bgView;
@property(nonatomic,strong) LoadingView* loadingView;
@end

@implementation LoadingUtil

+(instancetype)shareInstance
{
	static LoadingUtil* obj;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		obj = [[LoadingUtil alloc]init];
	});

	return obj;
}

+ (void)showLoading:(UIView *)view
{
	[view.window endEditing:YES];

	UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
	UIView* showView = view == nil ? keyWindow : view;

	[LoadingUtil hideLoading];

	LoadingView* loadingView = [[LoadingView alloc]init];
	loadingView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
	loadingView.layer.cornerRadius  = 10;
	loadingView.layer.masksToBounds = YES;

	UIView* bgView = [[UIView alloc]init];
	bgView.backgroundColor = [UIColor clearColor];

	LoadingUtil* obj = [LoadingUtil shareInstance];
	obj.bgView = bgView;
	obj.loadingView = loadingView;

	[showView addSubview:bgView];
	[showView addSubview:loadingView];

	[bgView mas_makeConstraints:^(MASConstraintMaker *make) {
		make.edges.equalTo(showView);
	}];

	[loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
		make.center.equalTo(showView);
		make.size.mas_equalTo(CGSizeMake(kLoadingWidth, kLoadingHeight));
	}];

	[loadingView startAnimating];
}

+ (void)hideLoading
{
	LoadingUtil* obj = [LoadingUtil shareInstance];
	[obj.loadingView stopAnimating];
	[obj.loadingView removeFromSuperview];
	[obj.bgView removeFromSuperview];
}

@end
