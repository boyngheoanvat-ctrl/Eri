#import "ToolWindow.h"
#import "ToolViewController.h"

@interface ToolWindow ()
@property (nonatomic, strong) ToolViewController *toolVC;
@end

@implementation ToolWindow

+ (instancetype)shared {
    static ToolWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect screen = [UIScreen mainScreen].bounds;

        // iOS 13+: dùng windowScene
        if (@available(iOS 13.0, *)) {
            UIWindowScene *scene = nil;
            for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
            if (scene) {
                instance = [[ToolWindow alloc] initWithWindowScene:scene];
                instance.frame = screen;
            } else {
                instance = [[ToolWindow alloc] initWithFrame:screen];
            }
        } else {
            instance = [[ToolWindow alloc] initWithFrame:screen];
        }

        instance.windowLevel = UIWindowLevelAlert + 100;
        instance.backgroundColor = [UIColor clearColor];
        instance.hidden = YES;

        instance.toolVC = [[ToolViewController alloc] init];
        instance.rootViewController = instance.toolVC;

        NSLog(@"[ToolWindow] Created");
    });
    return instance;
}

- (void)show {
    self.hidden = NO;
    [self makeKeyAndVisible];
    [self.toolVC reload];
    NSLog(@"[ToolWindow] SHOWN");
}

- (void)hide {
    self.hidden = YES;
    NSLog(@"[ToolWindow] HIDDEN");
}

- (void)toggle {
    if (self.hidden) [self show];
    else [self hide];
}

// Cho phép touch xuyên qua khi panel ẩn
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden) return nil;
    return [super hitTest:point withEvent:event];
}

@end
