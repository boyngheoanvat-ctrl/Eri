#import "ToolGestureManager.h"
#import "ToolWindow.h"

@interface ToolGestureManager () <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIWindow *targetWindow;
@property (nonatomic, strong) UITapGestureRecognizer *tripleTap;
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
            if (tap.numberOfTouchesRequired == 3) {
                NSLog(@"[ToolGesture] Already attached");
                return;
            }
        }
    }

    self.targetWindow = window;

    // Tap 3 ngón
    self.tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                              action:@selector(handleTripleTap:)];
    self.tripleTap.numberOfTouchesRequired = 3;
    self.tripleTap.numberOfTapsRequired = 1;
    self.tripleTap.cancelsTouchesInView = NO;
    self.tripleTap.delegate = self;
    [window addGestureRecognizer:self.tripleTap];

    NSLog(@"[ToolGesture] Attached 3-finger tap");
}

- (void)handleTripleTap:(UITapGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateEnded) {
        NSLog(@"[ToolGesture] 3-finger tap detected");
        [[ToolWindow shared] toggle];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return YES;
}

@end
