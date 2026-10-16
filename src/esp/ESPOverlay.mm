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
    @try {
        if (!self.overlay || !self.overlay.enabled) return;
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (!context) return;
        
        CGFloat centerX = CGRectGetWidth(rect) / 2.0;
        CGFloat centerY = CGRectGetHeight(rect) / 2.0;
        
        // Vẽ tâm định vị Master Toggle
        CGContextSetStrokeColorWithColor(context, [ToolTheme shared].accent.CGColor);
        CGContextSetLineWidth(context, 2.0);
        CGFloat radius = 80.0;
        CGRect circleRect = CGRectMake(centerX - radius, centerY - radius, radius * 2, radius * 2);
        CGContextStrokeEllipseInRect(context, circleRect);
        
        CGFloat dotRadius = 3.0;
        CGRect dotRect = CGRectMake(centerX - dotRadius, centerY - dotRadius, dotRadius * 2, dotRadius * 2);
        CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
        CGContextFillEllipseInRect(context, dotRect);
        
        // Render thực thể từ class finder
        NSArray<ESPTargetClass *> *targets = self.overlay.detectedTargets;
        if (!targets || targets.count == 0) return;
        
        for (ESPTargetClass *target in targets) {
            CGFloat tx = target.screenX;
            CGFloat ty = target.screenY;
            CGFloat tw = target.width > 0 ? target.width : 80.0;
            CGFloat th = target.height > 0 ? target.height : 160.0;
            
            if (tx <= -200 || ty <= -200) continue;
            
            if (self.overlay.showBox) {
                CGContextSetStrokeColorWithColor(context, [UIColor greenColor].CGColor);
                CGContextSetLineWidth(context, 1.5);
                CGContextStrokeRect(context, CGRectMake(tx - tw/2.0, ty, tw, th));
            }
            
            if (self.overlay.showLine) {
                CGContextSetStrokeColorWithColor(context, [UIColor yellowColor].CGColor);
                CGContextSetLineWidth(context, 1.0);
                CGContextMoveToPoint(context, centerX, 0);
                CGContextAddLineToPoint(context, tx, ty);
                CGContextStrokePath(context);
            }
            
            if (self.overlay.showDistance) {
                NSString *distText = [NSString stringWithFormat:@"[%.1fm]", target.distance];
                NSDictionary *attrs = @{
                    NSFontAttributeName: [UIFont boldSystemFontOfSize:10],
                    NSForegroundColorAttributeName: [UIColor cyanColor]
                };
                [distText drawAtPoint:CGPointMake(tx - 20, ty - 16) withAttributes:attrs];
            }
            
            if (self.overlay.showName && target.name.length > 0) {
                NSDictionary *nameAttrs = @{
                    NSFontAttributeName: [UIFont boldSystemFontOfSize:11],
                    NSForegroundColorAttributeName: [UIColor whiteColor]
                };
                [target.name drawAtPoint:CGPointMake(tx - 25, ty - 32) withAttributes:nameAttrs];
            }
            
            if (self.overlay.showHP) {
                CGFloat hpBarW = 4.0;
                CGFloat hpBarH = th;
                CGFloat healthRatio = target.health / 100.0;
                if (healthRatio < 0.0) healthRatio = 0.0;
                if (healthRatio > 1.0) healthRatio = 1.0;
                
                CGContextSetFillColorWithColor(context, [UIColor redColor].CGColor);
                CGContextFillRect(context, CGRectMake(tx - tw/2.0 - 8, ty, hpBarW, hpBarH));
                
                CGFloat currentHpHeight = hpBarH * healthRatio;
                CGContextSetFillColorWithColor(context, [UIColor greenColor].CGColor);
                CGContextFillRect(context, CGRectMake(tx - tw/2.0 - 8, ty + (hpBarH - currentHpHeight), hpBarW, currentHpHeight));
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[ESPOverlayView] Draw error: %@", e);
    }
}

@end

@interface ESPOverlayWindow : UIWindow
@end

@implementation ESPOverlayWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return NO;
}
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
    dispatch_once(&onceToken, ^{
        sharedInstance = [[ESPOverlay alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = NO;
        _showHP = YES;
        _showName = YES;
        _showDistance = YES;
        _showBox = YES;
        _showLine = YES;
        _mutableTargets = [NSMutableArray array];
        [self setupWindow];
    }
    return self;
}

- (void)setupWindow {
    dispatch_async(dispatch_get_main_queue(), ^{
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
    });
}

- (NSArray<ESPTargetClass *> *)detectedTargets {
    return [self.mutableTargets copy];
}

- (void)attachToWindow:(UIWindow *)window {
    if (self.overlayWindow) {
        self.overlayWindow.hidden = !self.enabled;
    }
}

- (void)show {
    self.enabled = YES;
    if (self.overlayWindow) {
        self.overlayWindow.hidden = NO;
    }
    self.displayLink.paused = NO;
}

- (void)hide {
    self.enabled = NO;
    if (self.overlayWindow) {
        self.overlayWindow.hidden = YES;
    }
    self.displayLink.paused = YES;
}

- (void)toggle {
    if (self.enabled) [self hide]; else [self show];
}

- (void)reload {
    [self.mutableTargets removeAllObjects];
    NSArray *found = [ESPClassFinder scanActiveTargets];
    if (found) [self.mutableTargets addObjectsFromArray:found];
    if (self.overlayView) [self.overlayView setNeedsDisplay];
}

- (void)updateESP {
    if (!self.enabled) return;
    [self.mutableTargets removeAllObjects];
    NSArray *targets = [ESPClassFinder scanActiveTargets];
    if (targets) [self.mutableTargets addObjectsFromArray:targets];
    if (self.overlayView) [self.overlayView setNeedsDisplay];
}

@end
