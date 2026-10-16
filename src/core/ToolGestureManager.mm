#import "ToolGestureManager.h"
#import "ToolWindow.h"

@interface ToolGestureManager () <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIWindow *targetWindow;
@property (nonatomic, strong) UITapGestureRecognizer *tripleTap;
@property (nonatomic, strong) UITapGestureRecognizer *doubleTapTwoFingers;
@end

@implementation ToolGestureManager

+ (instancetype)shared {
    static ToolGestureManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[ToolGestureManager alloc] init]; });
    return instance;
}

- (void)attachToWindow:(UIWindow *)window {
    if (!window) return;

    // Tránh attach nhiều lần
    for (UIGestureRecognizer *g in window.gestureRecognizers) {
        if ([g isKindOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)g;
            if (tap.numberOfTouchesRequired == 3 || tap.numberOfTouchesRequired == 2) {
                NSLog(@"[ToolGesture] Already attached");
                return;
            }
        }
    }

    self.targetWindow = window;

    // 1. Chạm 3 ngón để bật/mở lại menu
    self.tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                              action:@selector(handleTripleTap:)];
    self.tripleTap.numberOfTouchesRequired = 3;
    self.tripleTap.numberOfTapsRequired = 1;
    self.tripleTap.cancelsTouchesInView = NO;
    self.tripleTap.delegate = self;
    [window addGestureRecognizer:self.tripleTap];

    // 2. Chạm 2 ngón để ẩn nhanh menu
    self.doubleTapTwoFingers = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                     action:@selector(handleTwoFingerTap:)];
    self.doubleTapTwoFingers.numberOfTouchesRequired = 2;
    self.doubleTapTwoFingers.numberOfTapsRequired = 1;
    self.doubleTapTwoFingers.cancelsTouchesInView = NO;
    self.doubleTapTwoFingers.delegate = self;
    [window addGestureRecognizer:self.doubleTapTwoFingers];

    NSLog(@"[ToolGesture] Attached 3-finger (show) and 2-finger (hide) gestures");
}

- (void)handleTripleTap:(UITapGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateEnded) {
        NSLog(@"[ToolGesture] 3-finger tap detected -> showing menu");
        [[ToolWindow shared] show];
    }
}

- (void)handleTwoFingerTap:(UITapGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateEnded) {
        NSLog(@"[ToolGesture] 2-finger tap detected -> hiding menu");
        [[ToolWindow shared] hide];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

@end
