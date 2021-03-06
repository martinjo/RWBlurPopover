//
//  RWBlurPopoverView.h
//  RWBlurPopoverDemo
//
//  Created by Zhang Bin on 2014-10-16.
//  Copyright (c) 2014年 Zhang Bin. All rights reserved.
//

@import UIKit;

#import "pop.h"

@interface RWBlurPopoverView : UIView

@property (nonatomic, assign) float blurRadius;
@property (nonatomic, strong) UIView *blurView;
@property (nonatomic, strong) UIView *container;
@property (nonatomic, copy) dispatch_block_t dismissalBlock;

@property (nonatomic, assign, getter = isThrowingGestureEnabled) BOOL throwingGestureEnabled;
@property (nonatomic, assign, getter = isTapBlurToDismissEnabled) BOOL tapBlurToDismissEnabled;

- (instancetype)initWithContentView:(UIView *)contentView contentSize:(CGSize)contentSize blurRadius:(float)blurRadius;

- (void)animatePresentation;
- (void)animateDismissalWithCompletion:(dispatch_block_t)completion;

@end
