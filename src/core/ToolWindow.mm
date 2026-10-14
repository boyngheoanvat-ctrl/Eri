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
        instance.windowLevel = UIWindowLevelAlert + 100;
        instance.backgroundColor = [UIColor clearColor];
        instance.hidden = YES;

        instance.toolVC = [[ToolViewController alloc] init];
        instance.rootViewController = instance.toolVC;

        NSLog(@"[ToolWindow] Created, level=%.0f", instance.windowLevel);
    });
    return instance;
}

- (void)show {
    self.hidden = NO;
    [self makeKeyAndVisible];
    [self.toolVC reload];
    NSLog(@"[ToolWindow] SHOWN - hidden=%d, frame=%@",
          self.hidden, NSStringFromCGRect(self.frame));
}

- (void)hide {
    self.hidden = YES;
    NSLog(@"[ToolWindow] HIDDEN");
}

- (void)toggle {
    if (self.hidden) [self show];
    else [self hide];
}

@end
