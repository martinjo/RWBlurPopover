//
//  RWBlurPopoverView.m
//  RWBlurPopoverDemo
//
//  Created by Zhang Bin on 2014-10-16.
//  Copyright (c) 2014年 Zhang Bin. All rights reserved.
//

#import "RWBlurPopoverView.h"
#import "SABlurImageView.h"

static CGFloat angleOfView(UIView *view) {
    // http://stackoverflow.com/a/2051861/1271826
    return atan2(view.transform.b, view.transform.a);
}


typedef NS_ENUM(NSInteger, RWBlurPopoverViewState) {
    RWBlurPopoverViewStateInitial = 0,
    RWBlurPopoverViewStatePresenting,
    RWBlurPopoverViewStateShowing,
    RWBlurPopoverViewStateInteractiveDismissing,
    RWBlurPopoverViewStateAnimatedDismissing,
    RWBlurPopoverViewStateDismissed,
};

@interface RWBlurPopoverView ()

@property (nonatomic, strong) UIImage *origImage;
//@property (nonatomic, strong) UIImageView *blurredImageView;
@property (nonatomic, strong) SABlurImageView *blurredImageView;
@property (nonatomic, readwrite) float blur;

@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *backgroundTappingView;
@property (nonatomic, assign) CGSize contentSize;

@property (nonatomic, assign) RWBlurPopoverViewState state;

@property (nonatomic, strong) UIDynamicAnimator *animator;
@property (nonatomic, strong) UIAttachmentBehavior *attachmentBehavior;

@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@property (nonatomic, strong) UITapGestureRecognizer *backgroundTapGesture;

@property (nonatomic, assign) CGPoint interactiveStartPoint;
// compute angular velocity
@property (nonatomic, assign) CFTimeInterval interactiveLastTime;
@property (nonatomic, assign) CGFloat interactiveLastAngle;
@property (nonatomic, assign) CGFloat interactiveAngularVelocity;

@end

@implementation RWBlurPopoverView

- (instancetype)initWithContentView:(UIView *)contentView contentSize:(CGSize)contentSize {
    self = [super init];
    if (self) {
        self.contentView = contentView;
        self.contentSize = contentSize;
        self.state = RWBlurPopoverViewStateInitial;
        
        [self prepareBlurredImage];
        [self presentBlurredViewAnimated:YES];
      
        self.backgroundTappingView = [[UIView alloc] init];
        self.backgroundTappingView.backgroundColor = [UIColor clearColor];
        [self.backgroundTappingView addGestureRecognizer:self.backgroundTapGesture];
        
        [self addSubview:self.backgroundTappingView];
        [self addSubview:self.contentView];
        
        [self configureViewForState:self.state];
        
        [self.contentView addGestureRecognizer:self.panGesture];
    }
    return self;
}

- (void)configureViewForState:(RWBlurPopoverViewState)state {
    if (state >= RWBlurPopoverViewStateShowing) {
        self.contentView.transform = CGAffineTransformIdentity;
    } else  {
        CGFloat offset = (CGRectGetHeight(self.bounds) + self.contentSize.height) / 2.0;
        self.contentView.transform = CGAffineTransformMakeTranslation(0, -offset);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.blurView.frame = self.bounds;
    self.backgroundTappingView.frame = self.bounds;
    
    if (self.state <= RWBlurPopoverViewStateShowing) {
        self.contentView.frame = CGRectMake((CGRectGetWidth(self.bounds) - self.contentSize.width) / 2.0,
                                            (CGRectGetHeight(self.bounds) - self.contentSize.height) / 2.0,
                                            self.contentSize.width,
                                            self.contentSize.height
                                            );
    }
}

- (void)animatePresentation {
    [self layoutSubviews];
    [self configureViewForState:RWBlurPopoverViewStateInitial];
    self.state = RWBlurPopoverViewStatePresenting;
    [UIView animateWithDuration:0.5 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{
        [self configureViewForState:RWBlurPopoverViewStateShowing];
    } completion:^(BOOL finished) {
        self.state = RWBlurPopoverViewStateShowing;
    }];
}

- (void)animateDismissalWithCompletion:(void (^)(void))completion {
    if (self.state >= RWBlurPopoverViewStateAnimatedDismissing) {
        return;
    }
    self.state = RWBlurPopoverViewStateAnimatedDismissing;
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self];
    
    UIGravityBehavior *gravityBehavior = [[UIGravityBehavior alloc] initWithItems:@[self.contentView]];
    gravityBehavior.magnitude = 4;
    
    [self.animator addBehavior:gravityBehavior];
    
    UIDynamicItemBehavior *itemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.contentView]];
    {
        CGFloat angularVelocity = M_PI_2;
        if (arc4random() % 2 == 1) {
            angularVelocity = -M_PI_2;
        }
        angularVelocity *= 0.5;
        [itemBehavior addAngularVelocity:angularVelocity forItem:self.contentView];
    }
    
    [self.animator addBehavior:itemBehavior];

    __weak typeof(self) weakSelf = self;

    itemBehavior.action = ^{
        if (!CGRectIntersectsRect(self.bounds, self.contentView.frame)) {
            typeof(weakSelf) strongSelf = weakSelf;
            [strongSelf.animator removeAllBehaviors];
            strongSelf.animator = nil;
            
            strongSelf.state = RWBlurPopoverViewStateDismissed;
        }
    };
    [self removeBlurredViewAnimated:YES];
}

- (UIPanGestureRecognizer *)panGesture {
    if (!_panGesture) {
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    }
    return _panGesture;
}

- (UITapGestureRecognizer *)backgroundTapGesture {
    if (!_backgroundTapGesture) {
        _backgroundTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTapGesture:)];
    }
    return _backgroundTapGesture;
}

- (void)setThrowingGestureEnabled:(BOOL)throwingGestureEnabled {
    [self.panGesture setEnabled:throwingGestureEnabled];
}

- (BOOL)isThrowingGestureEnabled {
    return self.panGesture.isEnabled;
}

- (void)setTapBlurToDismissEnabled:(BOOL)tapBlurToDismissEnabled {
    [self.backgroundTapGesture setEnabled:tapBlurToDismissEnabled];
}

- (BOOL)isTapBlurToDismissEnabled {
    return self.backgroundTapGesture.enabled;
}

- (void)startInteractiveTransitionWithTouchLocation:(CGPoint)location {
    self.state = RWBlurPopoverViewStateInteractiveDismissing;
    self.interactiveStartPoint = location;
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:self];
    CGPoint anchorPoint = self.interactiveStartPoint;
    UIOffset anchorOffset = UIOffsetMake(anchorPoint.x - CGRectGetMidX(self.contentView.frame), anchorPoint.y - CGRectGetMidY(self.contentView.frame));
    self.attachmentBehavior = [[UIAttachmentBehavior alloc] initWithItem:self.contentView offsetFromCenter:anchorOffset attachedToAnchor:anchorPoint];

    // http://stackoverflow.com/questions/21325057/implement-uikitdynamics-for-dragging-view-off-screen
    self.interactiveLastTime = CACurrentMediaTime();
    self.interactiveLastAngle = angleOfView(self.contentView);
    __weak typeof(self) weakSelf = self;
    self.attachmentBehavior.action = ^{
        typeof(weakSelf) strongSelf = weakSelf;
        CFTimeInterval t = CACurrentMediaTime();
        CGFloat angle = angleOfView(strongSelf.contentView);
        if (t > strongSelf.interactiveLastTime)
        {
            CGFloat av = (angle - strongSelf.interactiveLastAngle) / (t - strongSelf.interactiveLastTime);
            if (fabs(av) > 1E-6)
            {
                strongSelf.interactiveAngularVelocity = av;
                strongSelf.interactiveLastTime = t;
                strongSelf.interactiveLastAngle = angle;
            }
        }
    };
    
    [self.animator addBehavior:self.attachmentBehavior];
}

- (void)updateInteractiveTransitionWithTouchLocation:(CGPoint)location {
    self.attachmentBehavior.anchorPoint = location;
    CGFloat distance = hypotf(self.interactiveStartPoint.x - location.x, self.interactiveStartPoint.y - location.y);
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    CGFloat screenHeight = screenRect.size.height;
    if(distance>0)
        self.blurredImageView.blur = 1.0-distance/screenHeight;
}

- (void)finishInteractiveTransitionWithTouchLocation:(CGPoint)location velocity:(CGPoint)velocity {
    // http://stackoverflow.com/questions/21325057/implement-uikitdynamics-for-dragging-view-off-screen
    
    self.state = RWBlurPopoverViewStateAnimatedDismissing;

    [self.animator removeAllBehaviors];
    
    UIDynamicItemBehavior *itemBehavior = [[UIDynamicItemBehavior alloc] initWithItems:@[self.contentView]];
    [itemBehavior addLinearVelocity:velocity forItem:self.contentView];
    [itemBehavior addAngularVelocity:self.interactiveAngularVelocity forItem:self.contentView];
    [itemBehavior setAngularResistance:2];
    
    __weak typeof(self) weakSelf = self;
    itemBehavior.action = ^{
        if (!CGRectIntersectsRect(weakSelf.bounds, weakSelf.contentView.frame))
        {
            weakSelf.state = RWBlurPopoverViewStateDismissed;
            [weakSelf.animator removeAllBehaviors];
        }
    };
    [self.animator addBehavior:itemBehavior];
    [self removeBlurredViewAnimated:YES];
}

- (void)cancelInteractiveTransitionWithTouchLocation:(CGPoint)location {
    [UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{
        [self.animator removeAllBehaviors];
        self.contentView.transform = CGAffineTransformIdentity;
        self.state = RWBlurPopoverViewStateShowing;
        [self layoutSubviews];
    } completion:^(BOOL finished) {
    }];
    [self animateBlur:1.0 duration:0.4];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)gr {
    CGPoint location = [gr locationInView:self];
    switch (gr.state) {
        case UIGestureRecognizerStateBegan: {
            [self startInteractiveTransitionWithTouchLocation:location];
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            [self updateInteractiveTransitionWithTouchLocation:location];
            break;
        }
            
        case UIGestureRecognizerStateEnded: case UIGestureRecognizerStateCancelled: {
            CGPoint velocity = [gr velocityInView:self];
            if (fabs(velocity.x) + fabs(velocity.y) <= 1000 || gr.state == UIGestureRecognizerStateCancelled) {
                [self cancelInteractiveTransitionWithTouchLocation:location];
            } else {
                [self finishInteractiveTransitionWithTouchLocation:location velocity:velocity];
            }

        }
        default: break;
    }
}

- (void)handleBackgroundTapGesture:(UITapGestureRecognizer *)gr {
    [self animateDismissalWithCompletion:nil];
}

- (UIImage *)imageFromView:(UIView *)v
{
    CGSize size = v.bounds.size;
    
    UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
    
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextScaleCTM(ctx, 1, 1);
    
    [v.layer renderInContext:ctx];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)prepareBlurredImage
{
    UIViewController *rootViewController = [UIApplication sharedApplication].keyWindow.rootViewController;

    UIImage *tmp = [self imageFromView:rootViewController.view];
    
    self.blurredImageView = [[SABlurImageView alloc]initWithImage:tmp];
    
    [self addSubview:self.blurredImageView];
}

- (void)presentBlurredViewAnimated:(BOOL)animated
{
    
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"before filter");
        [self.blurredImageView configrationForBlurAnimation:self.blurRadius];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (animated)
            {
                [self animateBlur:1.0 duration:0.4];
            }
            else
            {
                weakSelf.blurredImageView.blur=1.0;
            }
        });
    });
}

- (void)removeBlurredViewAnimated:(BOOL)animated
{
    if (!animated)
    {
        [self.blurredImageView removeFromSuperview];
    }
    else
    {
        float duration = 1-self.blur*0.4;
        
        [self animateBlur:0.0 duration:duration completed:^(POPAnimation *anim, BOOL finished)
         {
             POPBasicAnimation* fadeoutAnimation = [POPBasicAnimation animationWithPropertyNamed:kPOPViewAlpha];
             fadeoutAnimation.fromValue = @(self.blurredImageView.alpha);
             fadeoutAnimation.toValue = @(0.0);
             fadeoutAnimation.duration = 0.2;
             fadeoutAnimation.completionBlock =^(POPAnimation *anim, BOOL finished)
             {
                 [self.blurredImageView removeFromSuperview];
                 dispatch_async(dispatch_get_main_queue(), ^{
                     if (self.dismissalBlock) {
                         self.dismissalBlock();
                     }
                 });
             };
             [self.blurredImageView pop_addAnimation:fadeoutAnimation forKey:@"fadeoutAnimation"];
         }];
    }
}

+(POPAnimatableProperty*)blurProperty
{
    return [POPAnimatableProperty propertyWithName:@"blur" initializer:^(POPMutableAnimatableProperty *prop) {
        // read value
        prop.readBlock = ^(SABlurImageView *obj, CGFloat values[]) {
            values[0] = obj.blur;
        };
        // write value
        prop.writeBlock = ^(SABlurImageView *obj, const CGFloat values[]) {
            obj.blur=values[0];
        };
        // dynamics threshold
        prop.threshold = 0.01;
    }];
}

-(void)animateBlur:(float)blur duration:(float)duration
{
    [self animateBlur:blur duration:duration completed:nil];
}

-(void)animateBlur:(float)blur duration:(float)duration completed:(void(^)(POPAnimation *anim, BOOL finished))completed
{
    POPBasicAnimation* blurAnimation = [POPBasicAnimation linearAnimation];
    blurAnimation.property = [RWBlurPopoverView blurProperty];
    blurAnimation.fromValue = @(self.blurredImageView.blur);
    blurAnimation.toValue = @(blur);
    blurAnimation.duration = 0.5;
    blurAnimation.removedOnCompletion = true;
    blurAnimation.completionBlock = completed;
    [self.blurredImageView pop_addAnimation:blurAnimation forKey:@"blurInAnimation"];
}


@end
