#import "ToolWindow.h"
#import "ToolViewController.h"

@interface ToolWindow () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) ToolViewController *toolVC;
@property (nonatomic, strong) UIView *resizeHandle;
@property (nonatomic, assign) CGRect startFrame;
@property (nonatomic, assign) CGPoint panStartCenter;
@end

@implementation ToolWindow

+ (instancetype)shared {
    static ToolWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat initW = 480;
        CGFloat initH = 300;
        // Đặt vị trí xuất hiện ban đầu ở giữa màn hình (hoặc bất kỳ đâu tuỳ ý)
        CGFloat initX = (CGRectGetWidth(screen) - initW) / 2.0;
        CGFloat initY = (CGRectGetHeight(screen) - initH) / 2.0;
        CGRect initialRect = CGRectMake(initX, initY, initW, initH);

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
                            scene = (UIScene *)s;
                            break;
                        }
                    }
                }
                if (scene) {
                    instance = [[ToolWindow alloc] initWithWindowScene:scene];
                } else {
                    instance = [[ToolWindow alloc] initWithFrame:initialRect];
                }
            } else {
                instance = [[ToolWindow alloc] initWithFrame:initialRect];
            }
        } @catch (NSException *e) {
            instance = nil;
        }

        if (!instance) {
            instance = [[ToolWindow alloc] initWithFrame:initialRect];
        }

        instance.frame = initialRect;
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
            
            // 1. Thêm gesture kéo di chuyển toàn bộ menu (Drag Gesture cho cả view controller)
            UIPanGestureRecognizer *movePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMovePan:)];
            [self.toolVC.view addGestureRecognizer:movePan];
            
            // 2. Nút kéo phóng to/thu nhỏ ở góc phải dưới
            CGFloat handleSize = 24;
            self.resizeHandle = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.bounds) - handleSize - 4,
                                                                         CGRectGetHeight(self.bounds) - handleSize - 4,
                                                                         handleSize, handleSize)];
            self.resizeHandle.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:0.9];
            self.resizeHandle.layer.cornerRadius = 4;
            self.resizeHandle.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
            
            UIPanGestureRecognizer *resizePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResizePan:)];
            [self.resizeHandle addGestureRecognizer:resizePan];
            
            [self.toolVC.view addSubview:self.resizeHandle];
            [self.toolVC.view bringSubviewToFront:self.resizeHandle];
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

// Xử lý kéo di chuyển menu đi bất cứ đâu trên màn hình
- (void)handleMovePan:(UIPanGestureRecognizer * _Nonnull)pan {
    // Tránh xung đột khi người dùng đang kéo nút resize ở góc phải dưới
    CGPoint loc = [pan locationInView:self.toolVC.view];
    if (loc.x > CGRectGetWidth(self.bounds) - 45 && loc.y > CGRectGetHeight(self.bounds) - 45) {
        return;
    }
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.panStartCenter = self.center;
    } else if (pan.state == UIGestureRecognizerStateChanged || pan.state == UIGestureRecognizerStateEnded) {
        CGPoint translation = [pan translationInView:self.superview];
        self.center = CGPointMake(self.panStartCenter.x + translation.x, self.panStartCenter.y + translation.y);
    }
}

// Xử lý kéo thay đổi kích thước mượt mà không bị nhảy
- (void)handleResizePan:(UIPanGestureRecognizer * _Nonnull)pan {
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.startFrame = self.frame;
    } else if (pan.state == UIGestureRecognizerStateChanged || pan.state == UIGestureRecognizerStateEnded) {
        CGPoint translation = [pan translationInView:self];
        CGRect newFrame = self.startFrame;
        
        newFrame.size.width = MAX(320, newFrame.size.width + translation.x);
        newFrame.size.height = MAX(200, newFrame.size.height + translation.y);
        
        self.frame = newFrame;
        
        if (self.rootViewController) {
            self.rootViewController.view.frame = self.bounds;
        }
    }
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
