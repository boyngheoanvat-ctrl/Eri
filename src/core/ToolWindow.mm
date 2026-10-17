#import "ToolWindow.h"
#import "ToolViewController.h"

@interface ToolWindow () <UIGestureRecognizerDelegate>
@property (nonatomic, strong) ToolViewController *toolVC;
@property (nonatomic, strong) UIView *resizeHandle;
@end

@implementation ToolWindow

+ (instancetype)shared {
    static ToolWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Kích thước menu nhỏ lại ban đầu (ví dụ: width 480, height 300, căn giữa màn hình)
        CGRect screen = [UIScreen mainScreen].bounds;
        CGFloat initW = 480;
        CGFloat initH = 300;
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
                            scene = (UIWindowScene *)s;
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
            
            // Thêm nút kéo to nhỏ (Resize Handle) ở góc phải dưới menu
            CGFloat handleSize = 22;
            self.resizeHandle = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetWidth(self.bounds) - handleSize - 6,
                                                                         CGRectGetHeight(self.bounds) - handleSize - 6,
                                                                         handleSize, handleSize)];
            self.resizeHandle.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:0.8];
            self.resizeHandle.layer.cornerRadius = 4;
            self.resizeHandle.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
            
            // Gắn Pan Gesture để nhận thao tác kéo thay đổi kích thước
            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResizePan:)];
            [self.resizeHandle addGestureRecognizer:pan];
            
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

- (void)handleResizePan:(UIPanGestureRecognizer *)pan {
    CGPoint translation = [pan translationInView:self];
    if (pan.state == UIGestureRecognizerStateChanged || pan.state == UIGestureRecognizerStateEnded) {
        CGRect newFrame = self.frame;
        // Đặt giới hạn kích thước tối thiểu (Width >= 320, Height >= 200)
        newFrame.size.width = MAX(320, newFrame.size.width + translation.x);
        newFrame.size.height = MAX(200, newFrame.size.height + translation.y);
        
        self.frame = newFrame;
        [pan setTranslation:CGPointZero inView:self];
        
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
