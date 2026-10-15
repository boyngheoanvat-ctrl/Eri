#import "ESPOverlay.h"
#import "ToolTheme.h"

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
    
    CGContextSetLineWidth(context, 2.5);
    CGContextSetStrokeColorWithColor(context, [ToolTheme shared].success.CGColor);
    
    CGFloat boxW = 110;
    CGFloat boxH = 180;
    CGFloat boxX = (rect.size.width - boxW) / 2.0;
    CGFloat boxY = (rect.size.height - boxH) / 2.0;
    
    if (self.overlayController.showBox) {
        CGContextStrokeRect(context, CGRectMake(boxX, boxY, boxW, boxH));
    }
    if (self.overlayController.showLine) {
        CGContextMoveToPoint(context, rect.size.width / 2.0, rect.size.height);
        CGContextAddLineToPoint(context, boxX + boxW / 2.0, boxY + boxH);
        CGContextStrokePath(context);
    }
    
    UIFont *font = [[ToolTheme shared] monoBoldFont:11];
    NSDictionary *attrs = @{NSFontAttributeName: font, NSForegroundColorAttributeName: [UIColor cyanColor]};
    if (self.overlayController.showName) {
        [@"[Eri ESP All Active]" drawAtPoint:CGPointMake(boxX, boxY - 18) withAttributes:attrs];
    }
}

@end

@interface ESPOverlay ()
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) ESPOverlayView *espView;
@property (nonatomic, strong) CADisplayLink *displayLink;
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
    if (self.enabled && self.espView) [self.espView setNeedsDisplay];
}

- (void)show {
    self.enabled = YES;
    if (self.overlayWindow) {
        self.overlayWindow.hidden = NO;
        self.overlayWindow.alpha = 1.0;
        [self.overlayWindow makeKeyAndVisible];
    }
    if (self.espView) {
        self.espView.hidden = NO;
        [self.espView setNeedsDisplay];
    }
    if (self.displayLink) self.displayLink.paused = NO;
}

- (void)hide {
    self.enabled = NO;
    if (self.overlayWindow) self.overlayWindow.hidden = YES;
    if (self.displayLink) self.displayLink.paused = YES;
}

- (void)toggle {
    if (self.enabled) [self hide];
    else [self show];
}

- (void)reload {
    if (self.espView) [self.espView setNeedsDisplay];
}

@end
