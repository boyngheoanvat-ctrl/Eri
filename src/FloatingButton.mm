#import "FloatingButton.h"
#import "ToolWindow.h"
#import "ToolTheme.h"

@interface FloatingButton ()
@property (nonatomic, assign) BOOL hasMoved;
@end

@implementation FloatingButton

+ (void)attachToWindow:(UIWindow *)window {
    if (!window) return;

    // Tránh attach nhiều lần
    for (UIView *v in window.subviews) {
        if ([v isKindOfClass:[FloatingButton class]]) return;
    }

    FloatingButton *btn = [FloatingButton buttonWithType:UIButtonTypeCustom];
    CGFloat s = 56;
    btn.frame = CGRectMake(window.bounds.size.width - s - 16, 140, s, s);
    btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    btn.backgroundColor = [ToolTheme shared].accent;
    btn.layer.cornerRadius = s / 2.0;
    btn.layer.shadowColor = [UIColor blackColor].CGColor;
    btn.layer.shadowOpacity = 0.5;
    btn.layer.shadowRadius = 8;
    btn.layer.shadowOffset = CGSizeMake(0, 3);
    [btn setTitle:@"⚙" forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:26];
    [btn addTarget:btn action:@selector(toggleTool) forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:btn
                                                                          action:@selector(handlePan:)];
    [btn addGestureRecognizer:pan];

    [window addSubview:btn];
    [window bringSubviewToFront:btn];
}

- (void)handlePan:(UIPanGestureRecognizer *)g {
    CGPoint p = [g translationInView:self.superview];
    if (g.state == UIGestureRecognizerStateBegan) self.hasMoved = NO;
    if (fabs(p.x) > 2 || fabs(p.y) > 2) self.hasMoved = YES;
    self.center = CGPointMake(self.center.x + p.x, self.center.y + p.y);
    [g setTranslation:CGPointZero inView:self.superview];

    if (g.state == UIGestureRecognizerStateEnded && self.superview) {
        CGFloat w = CGRectGetWidth(self.superview.bounds);
        CGFloat tx = (self.center.x < w/2) ? 40 : (w - 40);
        [UIView animateWithDuration:0.25 animations:^{
            self.center = CGPointMake(tx, self.center.y);
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{ self.hasMoved = NO; });
    }
}

- (void)toggleTool {
    if (self.hasMoved) return;

    ToolWindow *tool = [ToolWindow shared];

    if (tool.hidden) {
        [tool show];
        self.backgroundColor = [ToolTheme shared].danger;
    } else {
        [tool hide];
        self.backgroundColor = [ToolTheme shared].accent;
    }
}

@end
