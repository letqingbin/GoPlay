//
//  LodingView.m
//  SFMoney
//
//  Created by dKingbin on 2018/7/18.
//  Copyright © 2018年 dKingbin. All rights reserved.
//

#import "LoadingView.h"

static NSString * const kSkypeCurveAnimationKey = @"kSkypeCurveAnimationKey";
static NSString * const kSkypeScaleAnimationKey = @"kSkypeScaleAnimationKey";

const float kLoadingWidth  = 90;
const float kLoadingHeight = 90;

@interface LoadingBubbleView()
@property (nonatomic, strong) UIColor* color;
@end

@implementation LoadingBubbleView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];
	if(self)
	{
		[self setBackgroundColor:[UIColor clearColor]];
	}

	return self;
}

- (void)drawRect:(CGRect)rect
{
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextClearRect(context, rect);
	CGContextAddEllipseInRect(context, self.bounds);
	CGContextSetFillColorWithColor(context, self.color.CGColor);
	CGContextFillPath(context);
}

@end

@interface LoadingView()
@property (nonatomic, assign) BOOL isAnimating;
@property (nonatomic, assign) BOOL removedOnCompletion;
@property (nonatomic, assign) NSInteger numberOfBubbles;
@property (nonatomic, strong) UIColor* bubbleColor;
@property (nonatomic, assign) CGSize bubbleSize;
@end

@implementation LoadingView

- (instancetype)initWithFrame:(CGRect)frame
{
	self = [super initWithFrame:frame];

	if(self)
	{
		self.isAnimating = NO;
		self.removedOnCompletion = NO;
		self.numberOfBubbles = 5;
		self.bubbleColor = [UIColor whiteColor];
		self.bubbleSize  = CGSizeMake(kLoadingWidth / 10.0f, kLoadingHeight / 10.0f);
	}

	return self;
}

- (void)startAnimating
{
	if(self.isAnimating) return;

	self.isAnimating = YES;

	for(NSUInteger i=0; i<self.numberOfBubbles; i++)
	{
		CGFloat x = i * (1.0f / self.numberOfBubbles);
		LoadingBubbleView *bubbleView = [self bubbleWithInitialScale:1.0f-x finalScale:0.2+x index:x];
		[bubbleView setAlpha:0.0f];
		[self addSubview:bubbleView];

		[UIView animateWithDuration:0.25f animations:^{
			[bubbleView setAlpha:1.0f];
		}];
	}
}

- (void)stopAnimating
{
	if(!self.isAnimating) return;

	for(UIView *bubble in self.subviews)
	{
		[UIView animateWithDuration:0.25f animations:^{
			[bubble setAlpha:0.0f];
		} completion:^(BOOL finished) {
			[bubble.layer removeAllAnimations];
			[bubble removeFromSuperview];
		}];
	}

	self.isAnimating = NO;
}

- (LoadingBubbleView *)bubbleWithInitialScale:(CGFloat)initialScale finalScale:(CGFloat)finalScale index:(CGFloat)x
{
	CAMediaTimingFunction* timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.5f :(0.1f + x) :0.25f :1.0f];

	LoadingBubbleView *bubbleView = [[LoadingBubbleView alloc] initWithFrame:CGRectMake(0, 0, self.bubbleSize.width, self.bubbleSize.height)];
	[bubbleView setColor:self.bubbleColor];

	CAKeyframeAnimation *pathAnimation = [CAKeyframeAnimation animationWithKeyPath:@"position"];
	pathAnimation.duration    =  1.5;
	pathAnimation.repeatCount =  CGFLOAT_MAX;
	pathAnimation.timingFunction = timingFunction;
	pathAnimation.path = [UIBezierPath bezierPathWithArcCenter:CGPointMake(kLoadingWidth/2, kLoadingHeight/2)
														radius:MIN(kLoadingWidth - bubbleView.bounds.size.width, kLoadingHeight - bubbleView.bounds.size.height)/2
													startAngle:3 * M_PI / 2
													  endAngle:3 * M_PI / 2 + 2 * M_PI
													 clockwise:YES].CGPath;
	pathAnimation.removedOnCompletion = self.removedOnCompletion;

	[bubbleView.layer addAnimation:pathAnimation forKey:kSkypeCurveAnimationKey];

	CABasicAnimation *scaleAnimation = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
	scaleAnimation.duration    = 1.5;
	scaleAnimation.repeatCount = CGFLOAT_MAX;
	scaleAnimation.fromValue = @(initialScale);
	scaleAnimation.toValue   = @(finalScale);
	scaleAnimation.removedOnCompletion = self.removedOnCompletion;

	if(initialScale > finalScale)
	{
		scaleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
	}
	else
	{
		scaleAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	}

	[bubbleView.layer addAnimation:scaleAnimation forKey:kSkypeScaleAnimationKey];

	return bubbleView;
}

@end
