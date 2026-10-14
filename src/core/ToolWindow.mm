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
        instance = [[ToolWindow alloc] initWithFrame:screen];
        instance.windowLevel = UIWindowLevelNormal + 1;
        instance.backgroundColor = [UIColor clearColor];
        instance.hidden = YES;

        instance.toolVC = [[ToolViewController alloc] init];
        instance.rootViewController = instance.toolVC;
    });
    return instance;
}

- (void)show {
    self.hidden = NO;
    [self makeKeyAndVisible];
    [self.toolVC reload];
}

- (void)hide {
    self.hidden = YES;
}

- (void)toggle {
    if (self.hidden) [self show];
    else [self hide];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];

    // Chỉ nhận touch khi panel đang hiện
    if (self.hidden) return nil;

    return hit;
}

@end
