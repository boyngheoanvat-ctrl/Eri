#import "ESPOverlay.h"
#import "ESPClassFinder.h"
#import "ToolTheme.h"
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

@interface ESPOverlayView : UIView
@property (nonatomic, weak) ESPOverlay *overlay;
@end

@implementation ESPOverlayView
- (instancetype)initWithFrame:(CGRect)frame overlay:(ESPOverlay *)overlay {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.overlay = overlay;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    @autoreleasepool {
        if (!self.overlay || !self.overlay.enabled) return;
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (!context) return;

        // Lấy danh sách mục tiêu thực thể đang hoạt động từ game
        NSArray<ESPTargetClass *> *targets = [ESPClassFinder scanActiveTargets];
        CGFloat screenWidth = CGRectGetWidth(rect);
        CGFloat screenHeight = CGRectGetHeight(rect);

        for (ESPTargetClass *target in targets) {
            CGFloat x = target.screenX;
            CGFloat y = target.screenY;
            CGFloat w = target.width > 0 ? target.width : 50.0;
            CGFloat h = target.height > 0 ? target.height : 100.0;

            // 1. Vẽ đường kẻ (Snaplines) từ giữa màn hình (hoặc đáy màn hình) tới mục tiêu
            CGContextSetStrokeColorWithColor(context, [ToolTheme shared].accent.CGColor);
            CGContextSetLineWidth(context, 1.0);
            CGContextBeginPath(context);
            CGContextMoveToPoint(context, screenWidth / 2.0, screenHeight); // Gốc từ đáy giữa màn hình
            CGContextAddLineToPoint(context, x, y);
            CGContextStrokePath(context);

            // 2. Vẽ hộp (Box ESP) bao quanh mục tiêu
            CGContextSetStrokeColorWithColor(context, [ToolTheme shared].accent.CGColor);
            CGContextSetLineWidth(context, 1.5);
            CGRect boxRect = CGRectMake(x - w / 2.0, y - h / 2.0, w, h);
            CGContextStrokeRect(context, boxRect);

            // 3. Vẽ thanh máu (HP Bar) phía trên hộp
            CGFloat hpPercentage = target.health > 0 ? (target.health / 100.0) : 1.0;
            CGFloat hpBarWidth = w;
            CGFloat hpCurrentWidth = hpBarWidth * hpPercentage;
            
            // Viền thanh máu
            CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
            CGContextSetLineWidth(context, 1.0);
            CGRect hpBorderRect = CGRectMake(x - w / 2.0, y - h / 2.0 - 8, hpBarWidth, 4);
            CGContextStrokeRect(context, hpBorderRect);
            
            // Lõi máu (Màu xanh thành công hoặc đỏ nếu thấp)
            UIColor *hpColor = (hpPercentage > 0.3) ? [ToolTheme shared].success : [UIColor redColor];
            CGContextSetFillColorWithColor(context, hpColor.CGColor);
            CGContextFillRect(context, CGRectMake(x - w / 2.0, y - h / 2.0 - 8, hpCurrentWidth, 4));

            // 4. Vẽ khoảng cách và tên (CM / Distance & Name) phía dưới hộp
            NSString *infoText = [NSString stringWithFormat:@"%@ (%.1fm)", target.name ?: @"Target", target.distance];
            NSDictionary *attrs = @{
                NSFontAttributeName: [[ToolTheme shared] monoFont:9],
                NSForegroundColorAttributeName: [UIColor whiteColor]
            };
            [infoText drawAtPoint:CGPointMake(x - w / 2.0, y + h / 2.0 + 4) withAttributes:attrs];
        }
    }
}
@end

@interface ESPOverlayWindow : UIWindow
@end
@implementation ESPOverlayWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event { return NO; }
@end

@interface ESPOverlay ()
@property (nonatomic, strong) ESPOverlayWindow *overlayWindow;
@property (nonatomic, strong) ESPOverlayView *overlayView;
@property (nonatomic, strong, readwrite) NSMutableArray<ESPTargetClass *> *mutableTargets;
@property (nonatomic, strong) CADisplayLink *displayLink;
@end

@implementation ESPOverlay
+ (instancetype)shared {
    static ESPOverlay *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ sharedInstance = [[ESPOverlay alloc] init]; });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = NO;
        _mutableTargets = [NSMutableArray array];
        @autoreleasepool {
            UIScreen *screen = [UIScreen mainScreen];
            self.overlayWindow = [[ESPOverlayWindow alloc] initWithFrame:screen.bounds];
            self.overlayWindow.windowLevel = UIWindowLevelAlert + 998;
            self.overlayWindow.backgroundColor = [UIColor clearColor];
            
            UIViewController *vc = [[UIViewController alloc] init];
            vc.view.backgroundColor = [UIColor clearColor];
            self.overlayWindow.rootViewController = vc;
            
            self.overlayView = [[ESPOverlayView alloc] initWithFrame:screen.bounds overlay:self];
            [vc.view addSubview:self.overlayView];
            self.overlayWindow.hidden = YES;
            
            self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateESP)];
            [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            self.displayLink.paused = YES;
        }
    }
    return self;
}

- (void)show {
    self.enabled = YES;
    self.overlayWindow.hidden = NO;
    self.displayLink.paused = NO;
}

- (void)hide {
    self.enabled = NO;
    self.overlayWindow.hidden = YES;
    self.displayLink.paused = YES;
}

- (void)toggle {
    if (self.enabled) [self hide];
    else [self show];
}

- (void)reload {
    @autoreleasepool {
        [self.mutableTargets removeAllObjects];
    }
}

- (void)updateESP {
    @autoreleasepool {
        if (self.overlayView) {
            [self.overlayView setNeedsDisplay];
        }
    }
}
@end
