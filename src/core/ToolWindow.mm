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

        @try {
            if (@available(iOS 13.0, *)) {
                UIWindowScene *scene = nil;
                for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                    if ([s isKindOfClass:[UIWindowScene class]] &&
                        s.activationState == UISceneActivationStateForegroundActive) {
                        scene = (UIWindowScene *)s;
                        break;
                    }
                }
                if (!scene) {
                    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
                        if ([s isKindOfClass:[UIWindowScene class]]) {
                            scene = (UIWindowScene *)s;
                            break;
                        }
                    }
                }
                if (scene) {
                    instance = [[ToolWindow alloc] initWithWindowScene:scene];
                } else {
                    instance = [[ToolWindow alloc] initWithFrame:screen];
                }
            } else {
                instance = [[ToolWindow alloc] initWithFrame:screen];
            }
        } @catch (NSException *e) {
            instance = nil;
        }

        if (!instance) {
            instance = [[ToolWindow alloc] initWithFrame:screen];
        }

        instance.frame = screen;
        instance.windowLevel = UIWindowLevelAlert + 100;
        instance.backgroundColor = [UIColor clearColor];
        instance.hidden = YES;
    });
    return instance;
}

- (void)show {
    if (!self.toolVC) {
        @try {
            self.toolVC = [[ToolViewController alloc] init];
            self.rootViewController = self.toolVC;
        } @catch (NSException *e) {
            return;
        }
    } 

    self.hidden = NO;
    [self makeKeyAndVisible];

    @try {
        [self.toolVC reload];
    } @catch (NSException *e) {}
}

- (void)hide {
    self.hidden = YES;
}

- (void)toggle {
    if (self.hidden) [self show];
    else [self hide];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden) return nil;
    return [super hitTest:point withEvent:event];
}

@end
