#import "ESPOverlay.h"
#import "ESPClassFinder.h"
#import "ToolTheme.h"
#import "IL2CPPResolver.h"
#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>

@interface ESPOverlayView : UIView
@property (nonatomic, weak) ESPOverlay *overlay;
@end

@implementation ESPOverlayView
- (instancetype)initWithFrame:(CGRect)frame overlay:(ESPOverlay *)overlay {
    self = [super initWithFrame:frame];
    if (self) { self.backgroundColor = [UIColor clearColor]; self.userInteractionEnabled = NO; self.overlay = overlay; }
    return self;
}
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    @autoreleasepool {
        if (!self.overlay || !self.overlay.enabled) return;
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (!context) return;
        CGFloat centerX = CGRectGetWidth(rect) / 2.0;
        CGFloat centerY = CGRectGetHeight(rect) / 2.0;
        CGContextSetStrokeColorWithColor(context, [ToolTheme shared].accent.CGColor);
        CGContextSetLineWidth(context, 2.0);
        CGRect circleRect = CGRectMake(centerX - 80, centerY - 80, 160, 160);
        CGContextStrokeEllipseInRect(context, circleRect);
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
        _enabled = NO; _mutableTargets = [NSMutableArray array];
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
- (void)show { self.enabled = YES; self.overlayWindow.hidden = NO; self.displayLink.paused = NO; }
- (void)hide { self.enabled = NO; self.overlayWindow.hidden = YES; self.displayLink.paused = YES; }
- (void)toggle { if (self.enabled) [self hide]; else [self show]; }
- (void)reload { @autoreleasepool { [self.mutableTargets removeAllObjects]; } }
- (void)updateESP { @autoreleasepool { if (self.overlayView) [self.overlayView setNeedsDisplay]; } }
@end
