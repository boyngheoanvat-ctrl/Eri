#import "ESPOverlay.h"
#import "ToolTheme.h"
#import "ESPClassFinder.h"
#import <mach/mach.h>

typedef struct { float x, y, z; } Vector3_t;
typedef struct { float x, y; } Vector2_t;

@interface ESPOverlayView : UIView
@property (nonatomic, weak) ESPOverlay *overlayController;
@end

@implementation ESPOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    if (!self.overlayController.enabled) return;
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) return;
    
    CGContextSetLineWidth(context, 2.0);
    
    NSArray<ESPTargetClass *> *targets = self.overlayController.detectedTargets;
    if (!targets || targets.count == 0) {
        CGContextSetStrokeColorWithColor(context, [ToolTheme shared].accent.CGColor);
        CGFloat boxW = 100, boxH = 160;
        CGFloat boxX = (rect.size.width - boxW) / 2.0;
        CGFloat boxY = (rect.size.height - boxH) / 2.0;
        
        if (self.overlayController.showBox) CGContextStrokeRect(context, CGRectMake(boxX, boxY, boxW, boxH));
        if (self.overlayController.showLine) {
            CGContextMoveToPoint(context, rect.size.width / 2.0, rect.size.height);
            CGContextAddLineToPoint(context, boxX + boxW / 2.0, boxY + boxH);
            CGContextStrokePath(context);
        }
        
        NSDictionary *attrs = @{NSFontAttributeName: [[ToolTheme shared] monoBoldFont:11], NSForegroundColorAttributeName: [UIColor yellowColor]};
        [@"[Auto-ESP] Scanning Game Memory..." drawAtPoint:CGPointMake(boxX - 20, boxY - 20) withAttributes:attrs];
        return;
    }

    for (ESPTargetClass *target in targets) {
        CGContextSetStrokeColorWithColor(context, [ToolTheme shared].success.CGColor);
        
        CGFloat boxW = 90, boxH = 150;
        CGFloat boxX = (rect.size.width - boxW) / 2.0;
        CGFloat boxY = (rect.size.height - boxH) / 2.0;
        
        if (self.overlayController.showBox) CGContextStrokeRect(context, CGRectMake(boxX, boxY, boxW, boxH));
        if (self.overlayController.showLine) {
            CGContextMoveToPoint(context, rect.size.width / 2.0, rect.size.height);
            CGContextAddLineToPoint(context, boxX + boxW / 2.0, boxY + boxH);
            CGContextStrokePath(context);
        }
        
        if (self.overlayController.showName) {
            NSDictionary *attrs = @{NSFontAttributeName: [[ToolTheme shared] monoBoldFont:10], NSForegroundColorAttributeName: [UIColor cyanColor]};
            NSString *label = [NSString stringWithFormat:@"[%@]", target.className];
            [label drawAtPoint:CGPointMake(boxX, boxY - 16) withAttributes:attrs];
        }
    }
}

@end

@interface ESPOverlay ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) ESPOverlayView *espView;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong, readwrite) NSArray<ESPTargetClass *> *detectedTargets;
@end

@implementation ESPOverlay

+ (instancetype)shared {
    static ESPOverlay *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[ESPOverlay alloc] init]; });
    return instance;
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
    }
    return self;
}

- (void)attachToWindow:(UIWindow *)window {
    if (self.overlayWindow) return;
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    
    if (@available(iOS 13.0, *)) {
        UIWindowScene *scene = window.windowScene;
        if (scene) self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
    }
    if (!self.overlayWindow) self.overlayWindow = [[UIWindow alloc] initWithFrame:screenBounds];
    
    self.overlayWindow.frame = screenBounds;
    self.overlayWindow.windowLevel = UIWindowLevelAlert + 99999;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.userInteractionEnabled = NO;
    
    self.espView = [[ESPOverlayView alloc] initWithFrame:screenBounds];
    self.espView.overlayController = self;
    
    UIViewController *emptyVC = [[UIViewController alloc] init];
    emptyVC.view = self.espView;
    self.overlayWindow.rootViewController = emptyVC;
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateESP)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    self.displayLink.paused = YES;
}

- (void)updateESP {
    if (self.enabled && self.espView) {
        [self.espView setNeedsDisplay];
    }
}

- (void)show {
    self.enabled = YES;
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSArray<ESPTargetClass *> *found = [[ESPClassFinder shared] scanForPotentialTargets];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.detectedTargets = found;
        });
    });

    if (self.overlayWindow) {
        self.overlayWindow.hidden = NO;
        self.overlayWindow.alpha = 1.0;
        [self.overlayWindow makeKeyAndVisible];
    }
    if (self.espView) {
        self.espView.hidden = NO;
        [self.espView setNeedsDisplay];
    }
    self.displayLink.paused = NO;
}

- (void)hide {
    self.enabled = NO;
    if (self.overlayWindow) self.overlayWindow.hidden = YES;
    self.displayLink.paused = YES;
}

- (void)toggle {
    if (self.enabled) [self hide];
    else [self show];
}

- (void)reload {
    if (self.espView) [self.espView setNeedsDisplay];
}

@end
