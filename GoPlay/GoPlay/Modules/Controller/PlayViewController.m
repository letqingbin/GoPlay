//
//  PlayViewController.m
//  GoPlay
//
//  Created by dKingbin on 2018/11/20.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "PlayViewController.h"

#import "ColorUtil.h"
#import "CommonUtil.h"
#import "Masonry.h"
#import "ReactiveCocoa.h"

#import "FFView.h"
#import "FFPlay.h"
#import "FFMovie.h"
#import "FFGLContext.h"

#import "FFVRFilter.h"
#import "SphereUtil.h"

#import "VideoView.h"

#import "FFUIElement.h"
#import "FFAlphaBendFilter.h"

@interface PlayViewController ()
@property(nonatomic,strong) FFView* ffView;
@property(nonatomic,strong) FFPlay* ffplay;
@property(nonatomic,strong) VideoView* controlView;

//0~1
@property(nonatomic,assign) float brightness;
@property(nonatomic,assign) float currentPanTime;
@property(nonatomic,assign,readonly) float duration;

@property(nonatomic,strong) FFVRFilter* vrfilter;
@property(nonatomic,strong) FFUIElement* watermark;
@property(nonatomic,strong) FFAlphaBendFilter* mixfilter;

@property(nonatomic,assign) BOOL isVROpen;
@property(nonatomic,assign) BOOL isWaterMarkOpen;
@property(nonatomic,assign) GLKVector3 anchorVector;
@property(nonatomic,assign) GLKVector3 currentVector;
@property(nonatomic,assign) GLKQuaternion lastQuaterion;
@property(nonatomic,assign) GLKQuaternion currentQuaterion;
@end

@implementation PlayViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	self.view.backgroundColor = UIColor.blackColor;
	self.currentPanTime = 0.0;
    
	self.isVROpen = NO;
	self.isWaterMarkOpen = NO;
    self.lastQuaterion = GLKQuaternionMake(0, 0, 0, 1);
    self.currentQuaterion = GLKQuaternionMake(0, 0, 0, 1);
    
	[self addSubviews];
	[self defineLayouts];
	[self setupVideo];
	[self setupObservers];
}

- (void)setUrl:(NSString *)url
{
	_url = url;
	self.ffplay.url = url;
}

- (void)addSubviews
{
	[self.view addSubview:self.ffView];
	[self.view addSubview:self.controlView];
}

- (void)defineLayouts
{
	[self.ffView mas_makeConstraints:^(MASConstraintMaker *make) {
		make.edges.equalTo(self.view);
	}];

	[self.controlView mas_makeConstraints:^(MASConstraintMaker *make) {
		make.edges.equalTo(self.view);
	}];
}

- (void)setupVideo
{
	self.ffplay.ffMovie.mode = FFRotationMode_R0;
	self.ffView.fillMode = FillModePreserveAspectRatio;

	[self.ffplay.ffMovie addTarget:self.ffView];
	
//	[self.ffplay.ffMovie addTarget:self.mixfilter atIndex:0];
//	[self.watermark addTarget:self.mixfilter atIndex:1];
//	[self.mixfilter addTarget:self.ffView];
//
//	[self.watermark update];
}

- (void)setupObservers
{
	@weakify(self)
	self.controlView.didGoBack = ^{
		@strongify(self)
		[self.ffplay destroy];
		[self.navigationController popViewControllerAnimated:YES];
	};

	self.controlView.didPlay = ^{
		@strongify(self)
		if(self.ffplay.state.playing)
		{
			[self.ffplay pause];
		}
		else
		{
			[self.ffplay play];
		}
	};

	self.controlView.didSeek = ^(float value) {
		@strongify(self)
		[self.ffplay seekToTimeByRatio:value];
	};

	self.controlView.didSeeking = ^(float value) {
		@strongify(self)
		if(value < 0) value = 0;
		if(value > 1) value = 1;
		float time = self.duration * value;
		float duration = self.duration;
		[self.controlView updateTime:time duration:duration];
	};

	self.controlView.didHorizontalStartPan = ^{
		@strongify(self)
		self.currentPanTime = self.ffplay.position;
		[self.controlView.tipsView updateTime:self.currentPanTime duration:self.duration];
	};

	self.controlView.didHorizontalPanning = ^(float offset) {
		@strongify(self)
		self.currentPanTime += offset;
		if(self.currentPanTime < 0) self.currentPanTime = 0;
		if(self.currentPanTime > self.duration) self.currentPanTime = self.duration;

		[self.controlView updateTime:self.currentPanTime duration:self.duration];
		[self.controlView.tipsView updateTime:self.currentPanTime duration:self.duration];
		[self.controlView updateSliderValue:self.currentPanTime/(float)self.duration];
	};

	self.controlView.didHorizontalEndPan = ^{
		@strongify(self)
		float value = self.currentPanTime / (float)self.duration;
		[self.controlView updateSliderValue:value];
		[self.ffplay seekToTimeByRatio:value];
	};

	self.controlView.volume = self.ffplay.audioController.volume;
	self.controlView.didUpdateVolume = ^(float value) {
		@strongify(self)
		self.ffplay.audioController.volume = value;
	};

	[RACObserve(self.ffplay.state, playing)
	 subscribeNext:^(id x) {
		 @strongify(self)
		 dispatch_async(dispatch_get_main_queue(), ^{
			 self.controlView.isPlay = self.ffplay.state.playing;
		 });
	 }];

	[RACObserve(self.ffplay.state, paused)
	 subscribeNext:^(id x) {
		 @strongify(self)
		 dispatch_async(dispatch_get_main_queue(), ^{
			 self.controlView.isPlay = self.ffplay.state.playing;
		 });
	 }];

	self.controlView.didVR = ^{
		@strongify(self)
		self.isVROpen = !self.isVROpen;
		if(self.isVROpen)
		{
			[self.controlView disablePanGesture];

			self.ffView.rotationMode = FFRotationMode_R180;

			[self.ffplay.ffMovie removeAllTargets];

			[self.vrfilter removeAllTargets];

			[self.ffplay.ffMovie addTarget:self.vrfilter];
			[self.vrfilter addTarget:self.ffView];
		}
		else
		{
			[self.controlView enablePanGesture];
			
			self.ffView.rotationMode = FFRotationMode_R0;

			[self.ffplay.ffMovie removeAllTargets];
			[self.vrfilter removeAllTargets];

			[self.ffplay.ffMovie addTarget:self.ffView];
            
            runAsync(^{
                self.currentQuaterion = GLKQuaternionMake(0, 0, 0, 1);
                self.lastQuaterion = self.currentQuaterion;
                self.vrfilter.currentQuaterion = self.currentQuaterion;
            });
		}
	};

	self.controlView.didFilter = ^{
		@strongify(self)
		self.isWaterMarkOpen = !self.isWaterMarkOpen;

		[self.ffplay.ffMovie removeAllTargets];
		[self.watermark removeAllTargets];
		[self.mixfilter removeAllTargets];

		if(self.isWaterMarkOpen)
		{
			[self.ffplay.ffMovie addTarget:self.mixfilter atIndex:0];
			[self.watermark addTarget:self.mixfilter atIndex:1];
			[self.mixfilter addTarget:self.ffView];

			[self.watermark update];
		}
		else
		{
			[self.ffplay.ffMovie addTarget:self.ffView];
		}
	};

	NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
	[defaultCenter addObserver:self
					  selector:@selector(ffPeriodicTime:)
						  name:kFFPeriodicTimeNotificationKey object:nil];

	[defaultCenter addObserver:self
					  selector:@selector(ffSeekCompleted:)
						  name:kFFSeekCompletedNotificationKey object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(onAppDidEnterBackground:)
												 name:UIApplicationDidEnterBackgroundNotification
											   object:nil];

	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(onAppWillEnterForeground:)
												 name:UIApplicationWillEnterForegroundNotification
											   object:nil];
}

- (void)ffPeriodicTime:(NSNotification *)notification
{
	if(self.controlView.isPanning) return;

	NSDictionary *userInfo = [notification userInfo];
	NSNumber* time = userInfo[@"time"];

	self.currentPanTime = time.floatValue;
}

- (void)ffSeekCompleted:(NSNotification *)notification
{
	dispatch_async(dispatch_get_main_queue(), ^{
		self.controlView.isPlay = YES;
	});
}

#pragma mark -- UIResponder
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if(!self.isVROpen) return;
    
    UITouch* touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.view];
    
    self.anchorVector = GLKVector3Make(location.x, location.y, 0);
    
	float radius = [SphereUtil sphereRadius];
	GLKVector3 center = [SphereUtil sphereCenter];
    
	self.anchorVector =	[SphereUtil projectOntoSurfaceByPoint:self.anchorVector
													   radius:radius
													   center:center];
    self.currentVector = self.anchorVector;
    self.lastQuaterion = self.currentQuaterion;
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
	if(!self.isVROpen) return;

    UITouch* touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.view];

	float radius = [SphereUtil sphereRadius];
	GLKVector3 center = [SphereUtil sphereCenter];
    
    self.currentVector = GLKVector3Make(location.x, location.y, 0);
	self.currentVector = [SphereUtil projectOntoSurfaceByPoint:self.currentVector
														radius:radius
														center:center];

    self.currentQuaterion = [SphereUtil computeQuaterionByStartQuaternion:self.lastQuaterion
                                                                   Anchor:self.anchorVector
                                                                  current:self.currentVector];
    runAsync(^{
        self.vrfilter.currentQuaterion = self.currentQuaterion;
    });
}

#pragma mark -- UIApplicationDidEnterBackgroundNotification
- (void)onAppDidEnterBackground:(UIApplication*)app
{
	[self.ffplay pause];
	self.controlView.isPlay = NO;

	[[FFGLContext shareInstance] useCurrentContext];
	glFinish();
}

#pragma mark -- UIApplicationWillEnterForegroundNotification
-(void)onAppWillEnterForeground:(UIApplication*)app
{
	[self.ffplay play];
	self.controlView.isPlay = YES;
}

- (void)setupOrientation
{
	[[UIDevice currentDevice] setValue:@(UIDeviceOrientationLandscapeLeft) forKey:@"orientation"];
	[UINavigationController attemptRotationToDeviceOrientation];
}

#pragma mark -- orientation
- (BOOL)shouldAutorotate
{
	return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskLandscapeRight;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	[self.navigationController setNavigationBarHidden:YES];
	[[UIApplication sharedApplication] setStatusBarHidden:YES];

	self.brightness = [[UIScreen mainScreen] brightness];

	//disable animate before orientation
	[UIView setAnimationsEnabled:NO];
    
    [self.ffplay play];
    self.controlView.isPlay = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];

	[self setupOrientation];

	//enable animate after orientation
	[UIView setAnimationsEnabled:YES];

	//disable idle
	[UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];

	[self.navigationController setNavigationBarHidden:NO];
	[[UIApplication sharedApplication] setStatusBarHidden:NO];

	[[UIScreen mainScreen] setBrightness:self.brightness];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];

	[[UIDevice currentDevice] setValue:@(UIDeviceOrientationPortrait) forKey:@"orientation"];
	[UINavigationController attemptRotationToDeviceOrientation];

	//enable idle
	[UIApplication sharedApplication].idleTimerDisabled = NO;
}

- (float)duration
{
	return self.ffplay.decoder.duration;
}

- (FFView *)ffView
{
	if(!_ffView)
	{
		_ffView = [[FFView alloc]initWithFrame:CGRectMake(0, 0, kScreenWidth, kScreenHeight)];
	}

	return _ffView;
}

- (FFPlay *)ffplay
{
	if(!_ffplay)
	{
		_ffplay = [[FFPlay alloc]init];
	}

	return _ffplay;
}

- (VideoView *)controlView
{
	if(!_controlView)
	{
		_controlView = [[VideoView alloc]init];
	}
	return _controlView;
}

- (FFVRFilter *)vrfilter
{
	if(!_vrfilter)
	{
		_vrfilter = [[FFVRFilter alloc]init];
	}

	return _vrfilter;
}

- (FFUIElement *)watermark
{
	if(!_watermark)
	{
		//1920x1080
		CGSize videoSize = CGSizeMake(1920, 1080);
		UIView* contentView = [[UIView alloc]initWithFrame:CGRectMake(0, 0, videoSize.width, videoSize.height)];
		contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		contentView.backgroundColor = UIColor.clearColor;

		UILabel* label = [CommonUtil LabelWithTitle:@"WaterMark!"
										  textColor:[UIColor orangeColor]
											bgColor:[UIColor greenColor]
											   font:60
									  textAlignment:NSTextAlignmentCenter
											   Bold:YES];
		[contentView addSubview:label];
		label.frame = CGRectMake(1920/2.0-250, 1080/2.0-100, 500, 200);

		self.mixfilter.mix = label.alpha;
		_watermark = [[FFUIElement alloc]initWithView:contentView];
	}
	return _watermark;
}

- (FFAlphaBendFilter *)mixfilter
{
	if(!_mixfilter)
	{
		_mixfilter = [[FFAlphaBendFilter alloc]init];
	}
	return _mixfilter;
}

- (void)dealloc
{
	self.ffplay = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
