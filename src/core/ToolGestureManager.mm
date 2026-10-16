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

    self.targetWindow = window;

    if (!self.tripleTap) {
        self.tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                  action:@selector(handleTripleTap:)];
        self.tripleTap.numberOfTouchesRequired = 3;
        self.tripleTap.numberOfTapsRequired = 1;
        self.tripleTap.cancelsTouchesInView = NO;
        self.tripleTap.delegate = self;
    }
    [window removeGestureRecognizer:self.tripleTap];
    [window addGestureRecognizer:self.tripleTap];

    [self attachGestureToToolWindow];
    NSLog(@"[ToolGesture] Attached gestures successfully");
}

- (void)attachGestureToToolWindow {
    ToolWindow *tool = [ToolWindow shared];
    if (tool) {
        if (!self.doubleTapTwoFingers) {
            self.doubleTapTwoFingers = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                             action:@selector(handleTwoFingerTap:)];
            self.doubleTapTwoFingers.numberOfTouchesRequired = 2;
            self.doubleTapTwoFingers.numberOfTapsRequired = 1;
            self.doubleTapTwoFingers.cancelsTouchesInView = NO;
            self.doubleTapTwoFingers.delegate = self;
        }
        [tool removeGestureRecognizer:self.doubleTapTwoFingers];
        [tool addGestureRecognizer:self.doubleTapTwoFingers];
    }
}

- (void)handleTripleTap:(UITapGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateEnded) {
        NSLog(@"[ToolGesture] 3-finger tap detected -> showing menu");
        ToolWindow *tool = [ToolWindow shared];
        [tool show];
        [self attachGestureToToolWindow];
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
